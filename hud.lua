return function(mod, menuColors)
  local Font = require("src.render.Font")
  local Growth = require("src.pokemon.Growth")
  local HudTiles = require("src.render.HudTiles")
  local PaletteFX = require("src.render.PaletteFX")
  local BattleState = require("src.battle.BattleState")
  local WideBattle = require("src.battle.WideBattle")

  local EXP_BLUE = { 42 / 255, 106 / 255, 208 / 255, 1 }
  local exposedStatuses = setmetatable({}, { __mode = "k" })
  local CAUGHT_ROW = { { hp = 1 } }
  local GENDER_MOD_ID = "gender_mod"
  local STAGED_GENDER_SCRATCH_X = 0
  local STAGED_GENDER_SCRATCH_Y = 87
  local STAGED_GENDER_CAPTURE_SIZE = 9
  local NATIVE_STAGED_GENDER_X_NUDGE = 1
  local stagedGenderCaptureDepth = 0
  local nativeStagedHudDepth = 0
  local nativeStagedOverlayDepth = 0
  local nativeStagedHudOwner = false
  local STAGED_COMPANIONS = {
    "DRAMATIC_SHAPE",
    "BATTLE_ART_VOXEL_FORK",
    "DRAMALESS_SHAPE",
  }

  local function setting()
    local ok, value = pcall(mod.options.get, mod.options, "battle_info")
    return not ok or value == nil or value == true
  end

  local function wideLayout(battle)
    if not (battle and type(battle.wideLayout) == "function") then
      return false
    end
    local ok, wide = pcall(battle.wideLayout, battle)
    return ok and wide == true
  end

  -- Dramatic Shape pins its staged renderer to the original 160x144 battle
  -- surface. These are the compatibility signals exposed by its live shot.
  local function stagedLayout(battle)
    return battle and (rawget(battle, "dramaticShapeShot") ~= nil
      or battle.letterboxWhite == false) or false
  end

  local function shownHP(battler)
    local mon = battler and battler.mon
    return math.max(0, math.floor((battler and battler.shownHP)
      or (mon and mon.hp) or 0))
  end

  local function battleColorMode(battle)
    if not (battle and type(battle.colorMode) == "function") then
      return false
    end
    local ok, enabled = pcall(battle.colorMode, battle)
    return ok and enabled == true
  end

  local function fitName(value, pixels)
    local text = tostring(value or "")
    if Font.width(text) <= pixels then return text end
    while #text > 0 and Font.width(text .. ".") > pixels do
      text = text:sub(1, -2)
    end
    return text .. "."
  end

  local function statusText(battle, battler)
    local status = battler
      and (battler.shownStatus or exposedStatuses[battler])
    if not status then return nil end
    if type(battle.statusLabel) == "function" then
      local ok, label = pcall(battle.statusLabel, battle, { status = status })
      if ok and label then return tostring(label) end
    end
    return tostring(status)
  end

  local function expProgress(data, mon)
    local def = data and data.pokemon and mon and data.pokemon[mon.species]
    if not def then return 0, 1, 0, false end
    local level = math.max(1, math.floor(mon.level or 1))
    local cap = data.constants and data.constants.levelCap or 100
    if level >= cap then return 0, 0, 1, true end
    local floorExp = Growth.expForLevel(def.growthRate, level,
      data.growth_rates)
    local nextExp = Growth.expForLevel(def.growthRate, level + 1,
      data.growth_rates)
    local needed = math.max(1, nextExp - floorExp)
    local current = math.max(0, math.min(needed,
      (mon.exp or floorExp) - floorExp))
    return current, needed, current / needed, false
  end

  local function shortNumber(value)
    if value < 1000 then return tostring(value) end
    if value < 1000000 then
      return tostring(math.floor(value / 1000 + 0.5)) .. "K"
    end
    return tostring(math.floor(value / 1000000 + 0.5)) .. "M"
  end

  local function isCaught(battle, battler)
    if battle.kind ~= "wild" then return false end
    local owned = battle.game and battle.game.save
      and battle.game.save.pokedex and battle.game.save.pokedex.owned
    local species = battler and battler.mon and battler.mon.species
    return species ~= nil and owned and owned[species] == true or false
  end

  local function drawCaughtBall(battle, x, y)
    if type(battle.drawBallRow) ~= "function" then return end
    local g = love.graphics
    local sx, sy, sw, sh = g.getScissor()
    g.setScissor(x, y, 8, 8)
    love.graphics.setColor(1, 1, 1, 1)
    battle:drawBallRow(CAUGHT_ROW, x, y, 8)
    if sx then g.setScissor(sx, sy, sw, sh) else g.setScissor() end
  end

  local function drawNativeHP(battle, battler, tx, ty, barType, segments,
      markColor, grayFill)
    HudTiles.drawHPBar(battle.data, tx, ty, {
      hp = shownHP(battler),
      stats = battler.mon.stats,
    }, barType, grayFill == true, segments)
    if markColor ~= false then
      PaletteFX.markTrueColor(tx * 8, ty * 8, (segments + 3) * 8, 8)
    end
  end

  -- A dark-HUD companion may whiten the native bar's dark tinted fill while
  -- it flips black glyphs. Re-seat just the two interior fill rows afterward
  -- with the same GREENBAR/YELLOWBAR/REDBAR palette decision as HudTiles.
  local function drawSemanticHpFill(battle, battler, tx, ty, segments)
    local hp = shownHP(battler)
    local maxHp = battler.mon.stats.hp
    local px = maxHp > 0 and math.floor(hp * segments * 8 / maxHp) or 0
    if hp > 0 then px = math.max(1, px) end
    if px <= 0 then return end
    local green = math.ceil(27 * segments / 6)
    local yellow = math.ceil(10 * segments / 6)
    local name = px >= green and "GREENBAR"
      or px >= yellow and "YELLOWBAR" or "REDBAR"
    local colors = PaletteFX.pal(battle.data, name)
    local c = colors and colors[3]
    local fallback = name == "GREENBAR" and { 0, 189, 0 }
      or name == "YELLOWBAR" and { 247, 165, 0 }
      or { 247, 0, 0 }
    c = c or fallback
    love.graphics.setColor(c[1] / 255, c[2] / 255, c[3] / 255, 1)
    love.graphics.rectangle("fill", tx * 8 + 16, ty * 8 + 3, px, 2)
  end

	local xpMarkImage

	local function getXpMarkImage()
	  if xpMarkImage ~= nil then
		return xpMarkImage or nil
	  end

	  local path = mod.path .. "/assets/xp_x.png"

	  local ok, img = pcall(love.graphics.newImage, path)

	  if not ok or not img then
		xpMarkImage = false
		return nil
	  end

	  img:setFilter("nearest", "nearest")

	  xpMarkImage = img
	  return img
	end

  -- Add a real EXP row directly above the HUD's native lower rule. Keep each
  -- native font tile on the integer pixel grid, but use a compact seven-pixel
  -- advance so the three glyphs fit beside the full-size numeric readout.
  -- The progress track spans the entire rule so its unfilled portion seats
  -- into the existing black line.
  local function drawExpMark(x, y)
    for i, glyph in ipairs({ "E", "X", "P" }) do
      Font.draw(glyph, x + (i - 1) * 7, y)
    end
  end

local function drawExpProgress(battle, battler, x, y, width, barY,
  markColor)

  local _, _, ratio = expProgress(battle.data, battler.mon)
  ratio = math.max(0, math.min(1, ratio or 0))

  -- Use the same native HP bar shell
  local tx = math.floor(x / 8)
  local ty = math.floor(y / 8)
  local segments = 10

  local fakeMax = 48
  local fakeHp = math.floor(fakeMax * ratio + 0.5)

  if ratio > 0 then
    fakeHp = math.max(1, fakeHp)
  end

  HudTiles.drawHPBar(battle.data, tx, ty, {
    hp = fakeHp,
    stats = { hp = fakeMax },
  }, nil, false, 11)

  -- Replace HP green fill with EXP blue
  local fill = math.floor(segments * 8 * ratio + 0.5)

  if ratio > 0 then
    fill = math.max(1, fill)
  end

  if fill > 0 then
    love.graphics.setColor(EXP_BLUE)
    love.graphics.rectangle(
      "fill",
      tx * 8 + 16,
      ty * 8 + 3,
      fill,
      2
    )
  end

  -- Cover only the H portion of the stock HP label
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.rectangle(
    "fill",
    tx * 8 + 1,
    ty * 8 + 2,
    4,
    4
  )

  -- Draw our custom X in the exact same spot
  local xpMark = getXpMarkImage()

  if xpMark then
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.draw(
      xpMark,
      tx * 8 + 1,
      ty * 8 + 2
    )
  end

  if markColor ~= false then
    PaletteFX.markTrueColor(
      tx * 8,
      ty * 8,
      (segments + 3) * 8,
      8
    )
  end
end

  local function enemyVisible(battle)
    local enemy = battle.enemy
    if not enemy or battle.showEnemyTrainer or battle.enemySendingOut
        or battle.introBalls or enemy.fainted then return false end
    if type(battle.growInScale) == "function" then
      local ok, scale = pcall(battle.growInScale, battle, enemy)
      if ok and scale then return false end
    end
    return true
  end

  local function playerVisible(battle)
    return battle.player ~= nil and not battle.safari and not battle.demo
      and not battle.showPlayerBack
  end

  -- Classic colorized battles run their finished 160x144 background through
  -- a second, internal SGB zone pass before the renderer's normal frame pass.
  -- HP can enter that pass as native shade gray, but a deliberately blue EXP
  -- pixel cannot. Re-seat only its filled pixels immediately after the battle
  -- zone pass; this is still part of the original HUD draw, before pics and
  -- animations are composited.
  local function drawClassicExpFill(battle)
    if not playerVisible(battle) then return end
    local _, _, ratio = expProgress(battle.data, battle.player.mon)
    ratio = math.max(0, math.min(1, ratio or 0))
    local fill = math.floor(80 * ratio + 0.5)
    if ratio > 0 then fill = math.max(1, fill) end
    if fill <= 0 then return end
    love.graphics.setColor(EXP_BLUE)
    love.graphics.rectangle("fill", 64, 90, fill, 1)
    PaletteFX.markTrueColor(64, 90, fill, 1)
  end

  local function drawStagedSemanticHpFills(battle)
    if enemyVisible(battle) then
      drawSemanticHpFill(battle, battle.enemy, 2, 2, 6)
    end
    if playerVisible(battle) then
      drawSemanticHpFill(battle, battle.player, 10, 8, 6)
    end
  end

  local function layoutFor(battle)
    if not setting() or not battle or battle.blankForAskName
        or (battle.introSlide or 0) > 0 then return nil end
    if wideLayout(battle) then return "wide" end
    if stagedLayout(battle) then return "staged" end
    return nil
  end

  local function drawStatus(battle, battler, levelX, y)
    local text = statusText(battle, battler)
    if not text then return end
    love.graphics.setColor(0, 0, 0, 1)
    Font.draw(text, levelX - Font.width(text) - 4, y)
  end

  local function drawStatusAt(battle, battler, x, y)
    local text = statusText(battle, battler)
    if not text then return end
    love.graphics.setColor(0, 0, 0, 1)
    Font.draw(text, x, y)
  end

  local function drawStatusAfterLevel(battle, battler, levelValueX, y,
      rightEdge)
    local text = statusText(battle, battler)
    if not text then return end
    local x = levelValueX + Font.width(tostring(battler.mon.level)) + 4
    if rightEdge then x = math.min(x, rightEdge - Font.width(text)) end
    love.graphics.setColor(0, 0, 0, 1)
    Font.draw(text, x, y)
  end

  local function drawLevel(battler, x, y)
    HudTiles.tile(0x6E, x, y)
    love.graphics.setColor(0, 0, 0, 1)
    Font.draw(tostring(battler.mon.level), x + 8, y)
  end

  local function nameX(tx, name)
    local count = #Font.split(name or "")
    return tx * 8 + (count <= 2 and 16 or count <= 4 and 8 or 0)
  end

  local function caughtBallX(name, x, maxNamePixels)
    local label = maxNamePixels and fitName(name, maxNamePixels)
      or tostring(name or "")
    return x + Font.width(label) + 2
  end

  local function drawPlayerUnderline(y)
    HudTiles.tile(0x73, 144, y - 16)
    HudTiles.tile(0x73, 144, y - 8)
    HudTiles.tile(0x77, 144, y)
    for i = 8, 17 do HudTiles.tile(0x76, i * 8, y) end
    HudTiles.tile(0x6F, 56, y)
  end

  -- The stock player HUD uses five 8px rows and spends its last row on the
  -- curve. Grow that same shape upward by one tile and leftward by two,
  -- leaving its
  -- lower and right edges fixed so it still meets Dramatic Shape's anchors.
  -- The extra row creates genuine EXP space; the extra width lets the native
  -- font keep a gap between the EXP label and current/required readout.
  local function drawStagedPlayerHud(battle, markColor, grayFill)
    local battler = battle.player
    love.graphics.setColor(0, 0, 0, 1)
    Font.draw(fitName(battler.name, 64), 80, 48)
    drawStatusAt(battle, battler, 80, 56)
    drawLevel(battler, 112, 56)
    drawNativeHP(battle, battler, 10, 8, 1, 6, markColor, grayFill)
    Font.draw(("%3d/%3d"):format(shownHP(battler), battler.mon.stats.hp),
      88, 72)
    drawPlayerUnderline(88)
    drawExpProgress(battle, battler, 64, 80, 80, 90, markColor)
  end

  local function clearStagedPlayerHud()
    local g = love.graphics
    if type(g.setBlendMode) == "function" then
      g.setBlendMode("replace", "premultiplied")
    end
    g.setColor(0, 0, 0, 0)
    g.rectangle("fill", 56, 48, 104, 48)
    if type(g.setBlendMode) == "function" then g.setBlendMode("alpha") end
  end

  -- These coordinates are the engine's original 160x144 HUD coordinates.
  -- This function is called while Dramatic Shape's native HUD texture is the
  -- active canvas, before that texture is snapped to the window edges.
  local function drawStagedHudContent(battle, alreadyCleared, markColor,
      grayFill)
    if enemyVisible(battle) then
      drawStatusAfterLevel(battle, battle.enemy, 40, 8, 88)
      drawNativeHP(battle, battle.enemy, 2, 2, nil, 6, markColor, grayFill)
      if isCaught(battle, battle.enemy) then
        local x = nameX(1, battle.enemy.name)
        drawCaughtBall(battle, caughtBallX(battle.enemy.name, x), 0)
      end
    end
    if playerVisible(battle) then
      if not alreadyCleared then clearStagedPlayerHud() end
      drawStagedPlayerHud(battle, markColor, grayFill)
    end
  end

local function renderWideEnemy(battle, fx)
  if not enemyVisible(battle) then return end

  local hudShake = (fx and fx.hudShakeX) or 0
  if hudShake ~= 0 then
    love.graphics.push()
    love.graphics.translate(hudShake, 0)
  end

  local battler = battle.enemy
  local enemyName = fitName(battler.name, 48)

  local shader
  local previousShader

  if battle.extendedHUD and battle:extendedHUD() and menuColors then
    shader = PaletteFX.shader()
    if shader then
      previousShader = love.graphics.getShader
        and love.graphics.getShader() or nil
      PaletteFX.sendColors(shader, menuColors())
      love.graphics.setShader(shader)
    end
  end

  love.graphics.setColor(0, 0, 0, 1)
  Font.drawBox(0, 0, 16, 4)
  Font.draw(enemyName, 8, 8)
  drawLevel(battler, 88, 8)
  drawStatusAfterLevel(battle, battler, 96, 8, 144)

  if isCaught(battle, battle.enemy) then
    drawCaughtBall(battle, caughtBallX(enemyName, 8), 8)
  end

  if shader then
    love.graphics.setShader(previousShader)
  end

drawNativeHP(battle, battle.enemy, 1, 2, nil, 11)

	if hudShake ~= 0 then
	  love.graphics.pop()
	end
end

local function renderWidePlayer(battle)
  if not playerVisible(battle) then return end

  local battler = battle.player

  local shader
  local previousShader

  if battle.extendedHUD and battle:extendedHUD() and menuColors then
    shader = PaletteFX.shader()
    if shader then
      previousShader = love.graphics.getShader
        and love.graphics.getShader() or nil
      PaletteFX.sendColors(shader, menuColors())
      love.graphics.setShader(shader)
    end
  end

  love.graphics.setColor(0, 0, 0, 1)
  Font.drawBox(23, 7, 15, 6)
  Font.draw(fitName(battler.name, 40), 192, 64)
  drawStatus(battle, battler, 264, 64)
  drawLevel(battler, 264, 64)

  Font.draw(("%3d/%3d"):format(shownHP(battler), battler.mon.stats.hp),
    240, 80)

  if shader then
    love.graphics.setShader(previousShader)
  end

  drawNativeHP(battle, battler, 24, 9, nil, 11)

  drawExpProgress(battle, battler, 192, 88, 96, 98)
end

	local function anchorWideHud(battle, x, y, w, h, anchor)
	  if not battle:extendedHUD() then return end

	  local stack = battle.game and battle.game.stack
	  if stack and stack.top and stack:top() ~= battle then return end

	  local renderer = battle.game and battle.game.renderer
	  if not (renderer and renderer.setBattleUIAnchor) then return end

	  x = x + (battle.extendedHUDOffsetX or 0)
	  y = y + (battle.extendedHUDOffsetY or 0)

	  local x2 = math.min(304, x + w)
	  local y2 = math.min(144, y + h)

	  x = math.max(0, x)
	  y = math.max(0, y)
	  w = x2 - x
	  h = y2 - y

	  if w > 0 and h > 0 then
		renderer:setBattleUIAnchor(x, y, w, h, anchor)
	  end
	end

	local function renderWide(battle)
	  
	  local function battleIsTopState(battle)
	  local stack = battle.game and battle.game.stack
	  return not (stack and stack.top) or stack:top() == battle
	end

	local function anchorHud(battle, x, y, w, h, anchor)
	  if not battle:extendedHUD() or not battleIsTopState(battle) then
		return
	  end

	  local renderer = battle.game and battle.game.renderer
	  if not (renderer and renderer.setBattleUIAnchor) then
		return
	  end

	  x = x + (battle.extendedHUDOffsetX or 0)
	  y = y + (battle.extendedHUDOffsetY or 0)

	  local x2 = math.min(304, x + w)
	  local y2 = math.min(144, y + h)

	  x = math.max(0, x)
	  y = math.max(0, y)

	  w = x2 - x
	  h = y2 - y

	  if w > 0 and h > 0 then
		renderer:setBattleUIAnchor(x, y, w, h, anchor)
	  end
	end

    local fx = battle.fx
    if fx and fx.flash and fx.flash > 0
        and (battle.frame or 0) % 4 < 2 then return end

    local sx = (fx and fx.shakeX) or 0
    local sy = (fx and fx.shakeY) or 0
    if sx == 0 and sy == 0 and fx and fx.shake and fx.shake > 0 then
      sx = (battle.frame or 0) % 4 < 2 and 2 or -2
    end
    love.graphics.push("all")
    if sx ~= 0 or sy ~= 0 then love.graphics.translate(sx, sy) end

	if not battle:extendedHUD() then
	  renderWideEnemy(battle, fx)
	end

	renderWidePlayer(battle)

	love.graphics.pop()
	end
  -- Draw-time presentation shim: while the engine paints its own HUD, expose
  -- the native level instead of the mutually-exclusive status label. The
  -- matching renderer then adds that saved status just to the left. No panel
  -- pixels are cleared or replaced, preserving the frosted background.
  local function withNativeLevels(battle, shortenNames, draw)
    local restores = {}
    local result
    local function expose(battler, nameWidth)
      if not (battler and battler.shownStatus) then return end
      restores[#restores + 1] = {
        battler = battler,
        status = battler.shownStatus,
        name = battler.name,
      }
      exposedStatuses[battler] = battler.shownStatus
      battler.shownStatus = nil
      if nameWidth then battler.name = fitName(battler.name, nameWidth) end
    end

    expose(battle.enemy, shortenNames and 48 or nil)
    expose(battle.player, shortenNames and 40 or nil)

    local ok, err = pcall(function() result = draw() end)
    for i = #restores, 1, -1 do
      local item = restores[i]
      item.battler.shownStatus = item.status
      item.battler.name = item.name
      exposedStatuses[item.battler] = nil
    end
    if not ok then error(err, 0) end
    return result
  end

	local originalWideDraw = WideBattle.draw
	WideBattle.draw = function(battle, ...)
	  local args = { ... }

	  local originalStatusHUDVisible = rawget(battle, "statusHUDVisible")
	  local renderer = battle.game and battle.game.renderer
	  local originalEndBattleHUDPass =
		renderer and renderer.endBattleHUDPass or nil

	  battle.statusHUDVisible = function()
		return false
	  end

	  if battle:extendedHUD()
		  and renderer
		  and originalEndBattleHUDPass then
		renderer.endBattleHUDPass = function(self, previous)
		  renderWideEnemy(battle, battle.fx)
		  anchorWideHud(battle, 0, 0, 152, 32, "top")
		  return originalEndBattleHUDPass(self, previous)
		end
	  end

	  local ok, result = pcall(function()
		return withNativeLevels(battle, true, function()
		  return originalWideDraw(battle, unpack(args))
		end)
	  end)

	  battle.statusHUDVisible = originalStatusHUDVisible

	  if renderer and originalEndBattleHUDPass then
		renderer.endBattleHUDPass = originalEndBattleHUDPass
	  end

	  if not ok then
		error(result, 0)
	  end

	  return result
	end

  -- In the normal 160x144 renderer the battle sprites and native HUD share
  -- one canvas. Render the native HUD into a transparent 160x144 layer first,
  -- edit that layer in place, then composite it where the original draw would
  -- have happened. This keeps the game's own tiles and drawing order without
  -- clearing holes through the battlefield underneath the player panel.
  local originalClassicDrawHUDs = BattleState.drawHUDs
  local classicHudLayer

  local function getClassicHudLayer()
    local g = love.graphics
    if classicHudLayer then return classicHudLayer end
    if type(g.newCanvas) ~= "function" then return nil end
    local ok, layer = pcall(g.newCanvas, 160, 144)
    if not ok or not layer then return nil end
    if type(layer.setFilter) == "function" then
      layer:setFilter("nearest", "nearest")
    end
    classicHudLayer = layer
    return classicHudLayer
  end

  local function classicEnhancementActive(battle, slide)
    return setting() and battle and slide == 0
      and not battle.blankForAskName
      and (battle.introSlide or 0) <= 0
      and not battle.introBalls
      and not wideLayout(battle)
      and not stagedLayout(battle)
  end

  local function drawClassicHud(battle, slide, args)
    local g = love.graphics
    if type(g.getCanvas) ~= "function" or type(g.setCanvas) ~= "function"
        or type(g.clear) ~= "function" or type(g.draw) ~= "function" then
      return originalClassicDrawHUDs(battle, slide, unpack(args))
    end
    local layer = getClassicHudLayer()
    if not layer then
      return originalClassicDrawHUDs(battle, slide, unpack(args))
    end

    local previous = g.getCanvas()
    local result
    local pushed = false
    local ok, err = xpcall(function()
      g.push("all")
      pushed = true
      g.setCanvas(layer)
      g.clear(0, 0, 0, 0)
      result = withNativeLevels(battle, false, function()
        local nativeResult = originalClassicDrawHUDs(battle, slide,
          unpack(args))
        drawStagedHudContent(battle, false, true, battleColorMode(battle))
        return nativeResult
      end)
      g.pop()
      pushed = false
      if previous then g.setCanvas(previous) else g.setCanvas() end

      g.push("all")
      pushed = true
      g.setColor(1, 1, 1, 1)
      g.draw(layer, 0, 0)
      g.pop()
      pushed = false
    end, debug.traceback)

    if pushed then pcall(g.pop) end
    if previous then g.setCanvas(previous) else g.setCanvas() end
    if not ok then error(err, 0) end
    return result
  end

  BattleState.drawHUDs = function(battle, slide, ...)
    local args = { ... }
    if not classicEnhancementActive(battle, slide) then
      return originalClassicDrawHUDs(battle, slide, unpack(args))
    end
    return drawClassicHud(battle, slide, args)
  end

  local originalClassicZonePass = BattleState.drawZonePass
  BattleState.drawZonePass = function(battle, ...)
    local result = originalClassicZonePass(battle, ...)
    if classicEnhancementActive(battle, 0) then
      drawClassicExpFill(battle)
    end
    return result
  end

  local function genderCompatibility(game)
    local exports = game and game.mods and game.mods.exports
    local api = exports and exports[GENDER_MOD_ID]
    local hud = api and api.BattleHUD
    if type(hud) ~= "table" then return nil, nil end
    return api, hud
  end

  -- Gender Mod 0.3.5 anchors the player glyph to the stock level row at
  -- y=64. Our player panel moves that level row to y=56, so teach its public
  -- BattleHUD contract the new coordinate while this HUD is enabled. Its
  -- overlay also normally hides the glyph whenever a status is present;
  -- expose the level slot just for that draw because our layout shows both.
  local function installGenderBridge(game)
    local _, hud = genderCompatibility(game)
    if not hud or hud.battleInfoHudCoordinatesV10 then return end

    if type(hud.classicGenderXY) == "function" then
      local originalClassicXY = hud.classicGenderXY
      hud.classicGenderXY = function(side, level)
        local x, y = originalClassicXY(side, level)
        if setting() and (nativeStagedHudDepth > 0
            or nativeStagedOverlayDepth > 0) then
          -- The authored gender art ends two transparent pixels before the
          -- level glyph. At Battle Art's large integer scale that reads as a
          -- loose gap, so close it by one native pixel without resampling.
          x = x + NATIVE_STAGED_GENDER_X_NUDGE
          if side == "player" then
            -- Force the stock level row even if this bridge was hot-reloaded
            -- on top of an older Battle Info HUD coordinate wrapper.
            y = 64
          end
          return x, y
        end
        if setting() and side == "player" then
          -- Battle Art 1.8+ captures the stock HUD unchanged. Its player
          -- name is still on y=56 and its level is still on y=64, so moving
          -- the gender tile to our enhanced y=56 row would split the name.
          if stagedGenderCaptureDepth > 0 then
            return STAGED_GENDER_SCRATCH_X, STAGED_GENDER_SCRATCH_Y
          end
          y = 56
        end
        return x, y
      end
    end

    if type(hud.wideGenderXY) == "function" then
      local originalWideXY = hud.wideGenderXY
      hud.wideGenderXY = function(side, level)
        local x, y = originalWideXY(side, level)
        if setting() and side == "player" then y = 56 end
        return x, y
      end
    end

    if type(hud.drawOverlay) == "function" then
      local originalOverlay = hud.drawOverlay
      hud.drawOverlay = function(battle, ...)
        if not setting() then return originalOverlay(battle, ...) end
        local args = { ... }
        local saved = {}
        local nativeStagedOverlay = nativeStagedHudOwner
          and stagedLayout(battle)
        for _, battler in pairs({ battle and battle.enemy,
            battle and battle.player }) do
          if battler and battler.shownStatus then
            saved[#saved + 1] = {
              battler = battler, status = battler.shownStatus,
            }
            battler.shownStatus = nil
          end
        end
        local result
        if nativeStagedOverlay then
          -- Gender Mod draws a second coloured glyph after Battle Art has
          -- captured the HUD. Keep that pass on the same stock level row as
          -- the captured glyph instead of repainting it through the name.
          nativeStagedOverlayDepth = nativeStagedOverlayDepth + 1
        end
        local ok, err = xpcall(function()
          result = originalOverlay(battle, unpack(args))
        end, debug.traceback)
        if nativeStagedOverlay then
          nativeStagedOverlayDepth = math.max(0,
            nativeStagedOverlayDepth - 1)
        end
        for i = #saved, 1, -1 do
          saved[i].battler.shownStatus = saved[i].status
        end
        if not ok then error(err, 0) end
        return result
      end
    end

    hud.battleInfoHudCoordinatesV10 = true
    mod.log:info("attached HUD coordinates to Gender Mod")
  end

  local genderCellLayer

  local function withStagedGenderCapture(draw)
    stagedGenderCaptureDepth = stagedGenderCaptureDepth + 1
    local result
    local ok, err = xpcall(function() result = draw() end, debug.traceback)
    stagedGenderCaptureDepth = math.max(0, stagedGenderCaptureDepth - 1)
    if not ok then error(err, 0) end
    return result
  end

  local function captureStagedGenderCell(battle, layer)
    local _, hud = genderCompatibility(battle and battle.game)
    if not (hud and type(hud.classicGenderXY) == "function"
        and hud.battleInfoHudCoordinatesV10
        and playerVisible(battle)) then return nil end
    local level = battle.player.mon and battle.player.mon.level or 1
    local okXY, targetX, targetY = pcall(hud.classicGenderXY,
      "player", level)
    if not okXY or type(targetX) ~= "number"
        or type(targetY) ~= "number" then
      return nil
    end

    local g = love.graphics
    if type(g.newCanvas) ~= "function" or type(g.clear) ~= "function"
        or type(g.draw) ~= "function" or type(g.getCanvas) ~= "function"
        or type(g.setCanvas) ~= "function" then return nil end
    if not genderCellLayer then
      -- The authored icon is 8x8. Dramatic Shape can add a one-pixel shadow
      -- down/right while baking the HUD, so retain that ninth edge too.
      local okCanvas, canvas = pcall(g.newCanvas,
        STAGED_GENDER_CAPTURE_SIZE, STAGED_GENDER_CAPTURE_SIZE)
      if not okCanvas or not canvas then return nil end
      if type(canvas.setFilter) == "function" then
        canvas:setFilter("nearest", "nearest")
      end
      genderCellLayer = canvas
    end

    local previous = g.getCanvas()
    g.push("all")
    g.setCanvas(genderCellLayer)
    g.clear(0, 0, 0, 0)
    g.setColor(1, 1, 1, 1)
    g.draw(layer, -STAGED_GENDER_SCRATCH_X,
      -STAGED_GENDER_SCRATCH_Y)
    g.pop()
    if previous then g.setCanvas(previous) else g.setCanvas() end
    return genderCellLayer, targetX, targetY
  end

  local function composeStagedTexture(battle, layer, inkPass)
    if not layer then return end
    local g = love.graphics
    if type(g.getCanvas) ~= "function" or type(g.setCanvas) ~= "function" then
      return
    end
    local previous = g.getCanvas()
    local genderCell, genderX, genderY =
      captureStagedGenderCell(battle, layer)
    g.push("all")
    g.setCanvas(layer)
    if genderCell then
      -- Gender Mod originally paints into a clean scratch cell so rebuilding
      -- the player HUD cannot copy name, underline or panel pixels along with
      -- its authored icon. Remove that staging cell before the band is moved.
      if type(g.setBlendMode) == "function" then
        g.setBlendMode("replace", "premultiplied")
      end
      g.setColor(0, 0, 0, 0)
      g.rectangle("fill", STAGED_GENDER_SCRATCH_X,
        STAGED_GENDER_SCRATCH_Y, STAGED_GENDER_CAPTURE_SIZE,
        STAGED_GENDER_CAPTURE_SIZE)
    end
    if type(g.setBlendMode) == "function" then g.setBlendMode("alpha") end
    if inkPass then
      -- Some Dramatic Shape forks bake white-on-dark HUD ink through a
      -- shader while creating the texture. Clear the original player block
      -- on the finished layer, then send our replacement glyphs through that
      -- same pass so they inherit the fork's current contrast treatment.
      if playerVisible(battle) then clearStagedPlayerHud() end
      inkPass(function() drawStagedHudContent(battle, true, false) end)
      drawStagedSemanticHpFills(battle)
    else
      drawStagedHudContent(battle, false, false)
    end
    if genderCell then
      g.setColor(1, 1, 1, 1)
      g.draw(genderCell, genderX, genderY)
    end
    g.pop()
    if previous then g.setCanvas(previous) else g.setCanvas() end
  end

  -- Dramatic Shape snapshots the original classic HUD into a 160x144 texture
  -- and then moves that texture to the window edges. Edit that texture before
  -- it is placed; staged battles never draw these additions afterward.
  local function installDramaticBridge(game, companionId)
    local exports = game and game.mods and game.mods.exports
    local api = exports and exports[companionId]
    local lib = api and api.lib
    if not (lib and type(lib.require) == "function") then return end
    local ok, overworld = pcall(lib.require, "OverworldBattle")
    if not ok or type(overworld) ~= "table"
        or type(overworld.hudTexture) ~= "function" then return end
    local innerHudTexture = overworld.hudTexture
    local innerSnapRects = overworld.snapRects
    local companionApi = exports and exports[companionId]
    local companionVersion = tostring(companionApi and companionApi.version
      or "0")
    local companionMajor, companionMinor = companionVersion:match(
      "^(%d+)%.(%d+)")
    local usesNativeStagedHud = companionId == "BATTLE_ART_VOXEL_FORK"
      and ((tonumber(companionMajor) or 0) > 1
        or ((tonumber(companionMajor) or 0) == 1
          and (tonumber(companionMinor) or 0) >= 8))
    if usesNativeStagedHud then nativeStagedHudOwner = true end
    if overworld.battleInfoHudTextureEditorV6 then return end

    -- Battle Art 1.8+ publishes and owns a complete snapped HUD pipeline.
    -- Repainting its private 160x144 capture through the older 1.7 bridge
    -- changes the block dimensions after the fork has already calculated its
    -- window-edge placement; in move selection that pulls names and HP bars
    -- back into the arena. Leave the fork's HUD capture and placement intact.
    -- The classic and engine-WIDE renderers remain enhanced below.
    if usesNativeStagedHud then
      overworld.hudTexture = function(liveBattle, ...)
        local args = { ... }
        nativeStagedHudDepth = nativeStagedHudDepth + 1
        local layer
        local okLayer, layerErr = xpcall(function()
          layer = innerHudTexture(liveBattle, unpack(args))
        end, debug.traceback)
        nativeStagedHudDepth = math.max(0, nativeStagedHudDepth - 1)
        if not okLayer then error(layerErr, 0) end
        return layer
      end
      overworld.battleInfoHudTextureEditorV6 = true
      mod.log:info("preserving %s %s native staged HUD coordinates",
        companionId, companionVersion)
      return
    end

    -- Dramatic Shape normally frosts the stock 40px-tall player HUD. Our
    -- texture keeps the same bottom/right edges but grows upward by one tile
    -- and leftward by two, so extend only the matching panel rect while it is
    -- enabled. OFF immediately restores Dramatic Shape's untouched geometry.
    if type(innerSnapRects) == "function" then
      overworld.snapRects = function(shot)
        local rects, bandPlacement = innerSnapRects(shot)
        if setting() and rects and rects.player and shot then
          local placement = bandPlacement and bandPlacement.player
          if type(placement) == "table" then
            -- BATTLE_ART_VOXEL_FORK can scale the snapped HUD separately
            -- from the battle letterbox and reports that exact placement.
            local scale = placement.scale or shot.scale or 1
            rects.player[1] = (placement.x or 0) + 56 * scale
            rects.player[2] = placement.y
              or ((shot.ly or 0) + 48 * scale)
            rects.player[3] = 104 * scale
            rects.player[4] = 48 * scale
          else
            -- Upstream Dramatic Shape keeps the band at shot.scale. Grow the
            -- returned native panel left/up without assuming its absolute x.
            local scale = shot.scale or 1
            rects.player[1] = rects.player[1] - 16 * scale
            rects.player[2] = rects.player[2] - 8 * scale
            rects.player[3] = rects.player[3] + 16 * scale
            rects.player[4] = rects.player[4] + 8 * scale
          end
        end
        return rects, bandPlacement
      end
    end

    overworld.hudTexture = function(liveBattle, ...)
      local args = { ... }
      if not setting() then
        return innerHudTexture(liveBattle, unpack(args))
      end
      installGenderBridge(liveBattle.game)
      local layer = withStagedGenderCapture(function()
        return withNativeLevels(liveBattle, false, function()
          return innerHudTexture(liveBattle, unpack(args))
        end)
      end)
      local inkPass
      if args[2] == true then
        local okHud, battleHud = pcall(lib.require, "BattleHud")
        if okHud and battleHud
            and type(battleHud.flipGlyphs) == "function" then
          inkPass = function(draw)
            return battleHud.flipGlyphs(160, 144, draw, args[3], nil,
              args[4])
          end
        end
      end
      composeStagedTexture(liveBattle, layer, inkPass)
      return layer
    end
    overworld.battleInfoHudTextureEditorV6 = true
    mod.log:info("attached staged HUD to %s", companionId)
  end

  local function installDramaticBridges(game)
    for _, companionId in ipairs(STAGED_COMPANIONS) do
      installDramaticBridge(game, companionId)
    end
  end

  mod.events:on("game.ready", function(ev)
    installGenderBridge(ev and ev.game)
    installDramaticBridges(ev and ev.game)
  end)

local originalBattlePalettes = BattleState.sgbPalettes

BattleState.sgbPalettes = function(battle, ...)
  local zones = originalBattlePalettes(battle, ...) or {}

  if not (battle and battle:wideLayout() and menuColors) then
    return zones
  end

  local palette = menuColors()

	if not (battle.extendedHUD and battle:extendedHUD()) then
	  zones[#zones + 1] = PaletteFX.zone(
		palette,
		0, 0,
		17, 3
	  )
	end

	if playerVisible(battle) then
	  zones[#zones + 1] = PaletteFX.zone(
		palette,
		23, 7,
		37, 12
	  )
	end

	return zones
	end

  mod.hooks:wrap("battle.overlay", function(next, battle)
    installGenderBridge(battle and battle.game)
    local layout = layoutFor(battle)
    if not layout then return next(battle) end
    if layout == "staged" then
      installDramaticBridges(battle.game)
      return next(battle)
    end
    next(battle)
    renderWide(battle)
  end, 50)
end

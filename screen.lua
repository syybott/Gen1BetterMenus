-- A single party-and-box workspace inspired by the storage screens in newer
-- Pokémon games. The engine's compact list-shaped Gen 1 saves stay intact;
-- this screen is only a controller and presentation layer over those lists.
return function(mod, genderExports, compatibility)
  compatibility = compatibility or {}
  local Assets = require("src.render.Assets")
  local Boxes = require("src.pokemon.Boxes")
  local Font = require("src.render.Font")
  local Logger = require("src.core.Logger")
  local PaletteFX = require("src.render.PaletteFX")
  local Party = require("src.pokemon.Party")
  local PartyMenu = require("src.ui.PartyMenu")
  local Renderer = require("src.render.Renderer")
  local Runtime = require("src.mods.Runtime")
  local Screens = require("src.ui.Screens")
  local Sound = require("src.core.Sound")
  local Sprites = require("src.pokemon.Sprites")
  local Stats = require("src.pokemon.Stats")
  local Strings = require("src.core.Strings")
  local TextBox = require("src.render.TextBox")
  local Theme = require("src.ui.Theme")

  local SCREEN_H = 144
  local HEADER_H = 16
  local FOOTER_Y = 135
  local WHITE = 1
  local LIGHT = 170 / 255
  local DARK = 85 / 255
  local BLACK = 0

  local TYPE_BASE = {
    NORMAL = { 144, 152, 162 }, FIGHTING = { 206, 63, 107 },
    FLYING = { 143, 168, 222 }, POISON = { 171, 106, 200 },
    GROUND = { 217, 119, 70 }, ROCK = { 201, 182, 139 },
    BUG = { 144, 192, 44 }, GHOST = { 82, 105, 173 },
    FIRE = { 254, 156, 85 }, WATER = { 77, 144, 214 },
    GRASS = { 101, 188, 94 }, ELECTRIC = { 244, 210, 59 },
    PSYCHIC = { 249, 113, 119 }, PSYCHIC_TYPE = { 249, 113, 119 },
    ICE = { 115, 206, 191 }, DRAGON = { 9, 109, 195 },
    DARK = { 91, 82, 101 }, FAIRY = { 236, 144, 231 },
    STEEL = { 91, 142, 161 },
  }

  local function typeRamp(base)
    local pale = {}
    for i = 1, 3 do
      pale[i] = math.floor(base[i] + (255 - base[i]) * 0.32 + 0.5)
    end
    return {
      { 255, 255, 255 }, pale,
      { base[1], base[2], base[3] }, { 0, 0, 0 },
    }
  end

  local TYPE_PALETTES = {}
  for key, color in pairs(TYPE_BASE) do
    TYPE_PALETTES[key] = typeRamp(color)
  end

  local PC = {}
  PC.__index = PC
  PC.isOpaque = true

  local inkShader -- false if the host has no shader support
  local fittedHgssIcons = {}

  local function iconAnimationEnabled(screen)
    local loader = screen and screen.game and screen.game.mods
    local options = loader and loader.modOptions
    local party = options and options.modern_party_ui
    return not party or party.animate_icons ~= false
  end

  local function animationCounter(screen)
    local counter = tonumber(screen and screen.blink) or 0
    -- Some compatibility wrappers draw the PC without advancing its local
    -- update counter. Real time keeps two-frame HGSS icons moving in that
    -- situation, while the counter remains the deterministic test fallback.
    if love.timer and love.timer.getTime then
      local ok, seconds = pcall(love.timer.getTime)
      if ok and tonumber(seconds) then
        counter = math.max(counter, math.floor(seconds * 60))
      end
    end
    return counter
  end

  local function animationFrame(screen, speed)
    if love.timer and love.timer.getTime then
      local ok, seconds = pcall(love.timer.getTime)
      -- HGSS's own PC presentation uses a steady two-frame pulse. Prefer
      -- that wall clock whenever it is running so a wrapped/frozen screen
      -- controller cannot strand every boxed Pokémon on frame one.
      if ok and tonumber(seconds) and seconds > 0 then
        return math.floor(seconds * 2) % 2 == 1
      end
    end
    return math.floor((tonumber(screen and screen.blink) or 0)
      / math.max(1, speed or 1)) % 2 == 1
  end

  local function gray(value)
    love.graphics.setColor(value, value, value, 1)
  end

  local function shaderForInk()
    if inkShader == nil then
      if not love.graphics.newShader then
        inkShader = false
      else
        local ok, shader = pcall(love.graphics.newShader, [[
          vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
            vec4 pixel = Texel(tex, tc);
            return vec4(color.rgb, pixel.a * color.a);
          }
        ]])
        inkShader = ok and shader or false
      end
    end
    return inkShader or nil
  end

  local function stripGenderSuffix(text)
    text = tostring(text or "")
    if not genderExports then return text end
    local plain = text:gsub("\226\153[\128\130]%s*$", "")
    if plain == text then plain = text:gsub("[♂♀]%s*$", "") end
    return plain
  end

  local function colorFromPalette(palette, shade)
    local color = palette and palette[shade]
    if type(color) ~= "table" then return nil end
    return color
  end

  local function fitText(text, maxWidth)
    text = tostring(text or "")
    maxWidth = math.max(0, math.floor(maxWidth or Font.width(text)))
    if Font.width(text) <= maxWidth then return text end
    local spans = Font.split(text)
    local count = Font.spansFitting(spans, math.max(0, maxWidth - 8))
    if count < 1 then return "" end
    return text:sub(1, spans[count].to) .. "."
  end

  local function drawText(text, x, y, maxWidth, shade)
    text = fitText(text, maxWidth or Font.width(tostring(text or "")))
    love.graphics.push("all")
    local shader = shaderForInk()
    if shader then
      love.graphics.setShader(shader)
      gray(shade == nil and WHITE or shade)
    else
      gray(BLACK)
    end
    Font.draw(text, math.floor(x), math.floor(y))
    love.graphics.pop()
    return Font.width(text)
  end

  local function drawCentered(text, cx, y, maxWidth, shade)
    text = fitText(text, maxWidth)
    drawText(text, cx - Font.width(text) / 2, y, maxWidth, shade)
  end

  local function drawRight(text, right, y, maxWidth, shade)
    text = fitText(text, maxWidth)
    drawText(text, right - Font.width(text), y, maxWidth, shade)
  end

  local function chamfer(mode, x, y, width, height, cut)
    cut = cut or 3
    if love.graphics.polygon then
      love.graphics.polygon(mode, {
        x + cut, y, x + width - cut, y,
        x + width, y + cut, x + width, y + height - cut,
        x + width - cut, y + height, x + cut, y + height,
        x, y + height - cut, x, y + cut,
      })
    else
      love.graphics.rectangle(mode, x, y, width, height)
    end
  end

  local function responsiveWidth()
    local width, height
    if love.graphics.getPixelDimensions then
      width, height = love.graphics.getPixelDimensions()
    else
      width, height = love.graphics.getDimensions()
    end
    width, height = tonumber(width) or 160, tonumber(height) or SCREEN_H
    local scale = math.max(1, math.floor(math.min(
      width / (Renderer.WIDTH or 160), height / SCREEN_H)))
    return math.min(Renderer.MAX_UI_WIDTH or 640,
      math.max(160, math.floor(width / scale)))
  end

  local function layoutFor(screen)
    local width = responsiveWidth()
    local renderer = screen and screen.game and screen.game.renderer
    if renderer and renderer.uiSize then
      width = select(1, renderer:uiSize()) or width
    end
    width = math.max(160, math.floor(width))

    if width < 252 then
      return {
        width = width, height = SCREEN_H, compact = true,
        party = { x = 2, y = 19, w = 43, h = 84, cols = 2, rows = 3 },
        box = { x = 48, y = 19, w = width - 50, h = 84, cols = 5, rows = 4 },
        detail = { x = 2, y = 106, w = width - 4, h = 28 },
      }
    end

    local partyW = math.min(96, math.max(72, math.floor(width * 0.25)))
    local detailW = math.min(112, math.max(64, math.floor(width * 0.25)))
    local boxX = partyW + 6
    return {
      width = width, height = SCREEN_H, compact = false,
      party = { x = 3, y = 17, w = partyW, h = 115, cols = 1, rows = 6 },
      box = { x = boxX, y = 17,
        w = width - boxX - detailW - 6, h = 115, cols = 5, rows = 4 },
      detail = { x = width - detailW - 3, y = 18, w = detailW, h = 114 },
    }
  end

  local function slotRect(layout, region, index)
    local panel = layout[region]
    local zero = index - 1
    local column = zero % panel.cols
    local row = math.floor(zero / panel.cols)
    local innerW, innerH = panel.w - 4, panel.h - 4
    local x1 = panel.x + 2 + math.floor(column * innerW / panel.cols)
    local x2 = panel.x + 2 + math.floor((column + 1) * innerW / panel.cols)
    local y1 = panel.y + 2 + math.floor(row * innerH / panel.rows)
    local y2 = panel.y + 2 + math.floor((row + 1) * innerH / panel.rows)
    return { x = x1, y = y1, w = x2 - x1, h = y2 - y1 }
  end

  local function panelFrame(panel, darkFace)
    gray(BLACK)
    chamfer("fill", panel.x + 1, panel.y + 1, panel.w, panel.h, 4)
    gray(darkFace and DARK or WHITE)
    chamfer("fill", panel.x, panel.y, panel.w, panel.h, 4)
    gray(darkFace and BLACK or LIGHT)
    chamfer("fill", panel.x + 2, panel.y + 2,
      panel.w - 4, panel.h - 4, 3)
  end

  local function monName(screen, mon)
    local def = mon and screen.game.data.pokemon[mon.species]
    return stripGenderSuffix(mon
      and (mon.nickname or (def and def.name) or mon.species) or "")
  end

  local function monPalette(screen, mon)
    local def = mon and screen.game.data.pokemon[mon.species]
    local primary = def and def.types and def.types[1]
    return TYPE_PALETTES[tostring(primary or "NORMAL"):upper()]
      or PaletteFX.monPal(screen.game.data, mon and mon.species)
      or PaletteFX.pal(screen.game.data, "BLUEMON")
  end

  local function ensurePartyMon(screen, mon)
    if not mon then return nil end
    Stats.ensure(screen.game.data.pokemon[mon.species], mon)
    return mon
  end

  local function play(screen, id)
    if screen.game and screen.game.data then Sound.play(screen.game.data, id) end
  end

  local function listFor(screen, region)
    if region == "party" then return screen.game.save.party, Party.MAX end
    return Boxes.active(screen.game.save), Boxes.CAPACITY
  end

  local function selected(screen)
    local list = listFor(screen, screen.region)
    local index = screen.region == "party" and screen.partyIndex or screen.boxIndex
    return list[index], list, index
  end

  local function selectedPalette(screen)
    return PaletteFX.pal(screen.game.data, "YELLOWMON")
      or PaletteFX.pal(screen.game.data, "REDMON")
      or monPalette(screen, selected(screen))
  end

  local function currentIndex(screen)
    return screen.region == "party" and screen.partyIndex or screen.boxIndex
  end

  local function setCurrentIndex(screen, index)
    if screen.region == "party" then
      screen.partyIndex = math.max(1, math.min(Party.MAX, index))
    else
      screen.boxIndex = math.max(1, math.min(Boxes.CAPACITY, index))
    end
  end

  local function beginBoxSwitcher(screen)
    if screen.boxSwitching then return end
    screen.boxSwitchReturnRegion = screen.held and "box" or screen.region
    screen.region = "box"
    screen.boxSwitching = true
    screen.status = nil
    play(screen, "Press_AB")
  end

  local function endBoxSwitcher(screen)
    if not screen.boxSwitching then return end
    screen.boxSwitching = false
    screen.region = screen.boxSwitchReturnRegion or "box"
    screen.boxSwitchReturnRegion = nil
    screen.status = nil
    play(screen, "Press_AB")
  end

  local function nearestIndex(layout, region, sourceY, enteringFromLeft)
    local panel = layout[region]
    local capacity = region == "party" and Party.MAX or Boxes.CAPACITY
    local best, distance = 1, math.huge
    for index = 1, capacity do
      local zero = index - 1
      local column = zero % panel.cols
      local desiredColumn = enteringFromLeft and 0 or (panel.cols - 1)
      if column == desiredColumn then
        local rect = slotRect(layout, region, index)
        local d = math.abs(rect.y + rect.h / 2 - sourceY)
        if d < distance then best, distance = index, d end
      end
    end
    return best
  end

  local function moveCursor(screen, direction)
    local layout = layoutFor(screen)
    local panel = layout[screen.region]
    local index = currentIndex(screen)
    local zero = index - 1
    local column, row = zero % panel.cols, math.floor(zero / panel.cols)

    if direction == "left" then
      if column > 0 then
        setCurrentIndex(screen, index - 1)
      elseif screen.region == "box" then
        local rect = slotRect(layout, "box", index)
        screen.region = "party"
        screen.partyIndex = nearestIndex(layout, "party",
          rect.y + rect.h / 2, false)
      end
    elseif direction == "right" then
      if column < panel.cols - 1 then
        setCurrentIndex(screen, index + 1)
      elseif screen.region == "party" then
        local rect = slotRect(layout, "party", index)
        screen.region = "box"
        screen.boxIndex = nearestIndex(layout, "box",
          rect.y + rect.h / 2, true)
      end
    elseif direction == "up" then
      if row > 0 then
        setCurrentIndex(screen, index - panel.cols)
      elseif screen.region == "box" then
        beginBoxSwitcher(screen)
      end
    elseif direction == "down" and row < panel.rows - 1 then
      setCurrentIndex(screen, index + panel.cols)
    end
  end

  local function deposited(screen, mon)
    require("src.world.PikachuFollower")
      .modifyHappiness(screen.game.save, "DEPOSITED", mon)
  end

  local function finishMove(screen, targetList, targetIndex, targetCapacity)
    local held = screen.held
    if not held or held.sourceList[held.sourceIndex] ~= held.mon then
      screen.held = nil
      screen.status = Strings("That POKéMON moved already.")
      return false
    end

    local sourceList, sourceIndex, mon = held.sourceList, held.sourceIndex, held.mon
    local sourceParty = sourceList == screen.game.save.party
    local targetParty = targetList == screen.game.save.party
    local targetMon = targetList[targetIndex]

    if sourceList == targetList then
      if sourceIndex == targetIndex then
        screen.held = nil
        screen.status = Strings("Put %s back.", monName(screen, mon))
        return true
      end
      if targetMon then
        sourceList[sourceIndex], sourceList[targetIndex] =
          sourceList[targetIndex], sourceList[sourceIndex]
      else
        table.remove(sourceList, sourceIndex)
        if sourceIndex < targetIndex then targetIndex = targetIndex - 1 end
        table.insert(targetList, math.min(targetIndex, #targetList + 1), mon)
      end
    elseif targetMon then
      sourceList[sourceIndex], targetList[targetIndex] = targetMon, mon
      if sourceParty then ensurePartyMon(screen, targetMon) end
      if targetParty then ensurePartyMon(screen, mon) end
      if sourceParty and not targetParty then
        deposited(screen, mon)
      elseif targetParty and not sourceParty then
        deposited(screen, targetMon)
      end
    else
      if #targetList >= targetCapacity then
        screen.status = targetParty and Strings("The party is full!")
          or Strings("This BOX is full!")
        return false
      end
      if sourceParty and not targetParty and #sourceList <= 1 then
        screen.status = Strings("Keep one POKéMON in your party!")
        return false
      end
      table.remove(sourceList, sourceIndex)
      if targetParty then ensurePartyMon(screen, mon) end
      table.insert(targetList, math.min(targetIndex, #targetList + 1), mon)
      if sourceParty and not targetParty then deposited(screen, mon) end
    end

    screen.held = nil
    screen.status = Strings("Moved %s.", monName(screen, mon))
    play(screen, "Swap")
    return true
  end

  local function pickOrDrop(screen)
    local mon, list, index = selected(screen)
    if screen.held then
      local _, capacity = listFor(screen, screen.region)
      return finishMove(screen, list, index, capacity)
    end
    if not mon then
      screen.status = Strings("That slot is empty.")
      return false
    end
    screen.held = {
      mon = mon, sourceList = list, sourceIndex = index,
      sourceRegion = screen.region,
      sourceBox = screen.region == "box" and screen.game.save.currentBox or nil,
    }
    screen.status = Strings("Where should %s go?", monName(screen, mon))
    play(screen, "Press_AB")
    return true
  end

  local function switchBox(screen, delta)
    local count = Boxes.COUNT
    screen.game.save.currentBox =
      ((screen.game.save.currentBox - 1 + delta) % count) + 1
    screen.status = Strings("Opened BOX %02d.", screen.game.save.currentBox)
    if screen.game.writeSave then screen.game:writeSave() end
    play(screen, "Swap")
  end

  local function quickTransfer(screen)
    local mon, source, index = selected(screen)
    if not mon then
      screen.status = Strings("That slot is empty.")
      return false
    end

    if screen.region == "party" then
      local box = Boxes.active(screen.game.save)
      if #source <= 1 then
        screen.status = Strings("Keep one POKéMON in your party!")
        return false
      end
      if #box >= Boxes.CAPACITY then
        screen.status = Strings("This BOX is full!")
        return false
      end
      table.remove(source, index)
      table.insert(box, mon)
      deposited(screen, mon)
      screen.status = Strings("Sent %s to BOX %02d.", monName(screen, mon),
        screen.game.save.currentBox)
    else
      local party = screen.game.save.party
      if #party >= Party.MAX then
        screen.status = Strings("The party is full!")
        return false
      end
      table.remove(source, index)
      ensurePartyMon(screen, mon)
      table.insert(party, mon)
      screen.status = Strings("Added %s to the party.", monName(screen, mon))
    end
    play(screen, "Withdraw_Deposit")
    return true
  end

  local function requestRelease(screen)
    local mon, list, index = selected(screen)
    if not mon then
      screen.status = Strings("That slot is empty.")
      return false
    end
    if list == screen.game.save.party and #list <= 1 then
      screen.status = Strings("You can't release your last POKéMON!")
      return false
    end

    local name = monName(screen, mon)
    screen.game.stack:push(TextBox.new(screen.game,
      Strings("Release %s?\nGone forever!", name), nil, {
        defaultNo = true, noSound = true,
        choice = function(yes)
          if not yes then
            screen.status = Strings("Release cancelled.")
            return
          end
          if list[index] ~= mon then return end
          table.remove(list, index)
          Sound.playCry(screen.game.data, mon.species)
          screen.status = Strings("Released %s.", name)
          screen.game.stack:push(TextBox.new(screen.game,
            Strings("%s was released.\fBye %s!", name, name)))
        end,
      }))
    return true
  end

  local function actionItems(screen)
    local mon = selected(screen)
    local items = {}
    if mon then
      items[#items + 1] = { label = Strings("SUMMARY"), action = "summary" }
      items[#items + 1] = {
        label = screen.region == "party" and Strings("SEND TO BOX")
          or Strings("ADD TO PARTY"),
        action = "transfer",
      }
      items[#items + 1] = { label = Strings("RELEASE"), action = "release" }

      -- Party companion mods use this shared hook for utility actions such as
      -- NICKNAME and FOLLOW. Boxed Pokémon are deliberately excluded: those
      -- actions describe the active party and may alter overworld state.
      if screen.region == "party" then
        local original = items
        local hooked = Runtime.call("ui.party.submenu",
          function(_, entries) return entries end,
          screen.game, items, mon, {
            battle = false,
            overworld = screen.game.overworld,
            storage = true,
            pc = true,
          })
        if type(hooked) == "table" then
          items = hooked
        else
          items = original
          Logger.error("ui.party.submenu returned %s; keeping PC actions",
            type(hooked))
        end
      end
    end
    items[#items + 1] = { label = Strings("CANCEL"), action = "cancel" }
    return items
  end

  local function runAction(screen, entry)
    if not entry then return end
    local action = entry.action
    screen.actions = nil
    if not action and type(entry.onSelect) == "function" then
      local mon = selected(screen)
      if mon then entry.onSelect(mon, screen.game) end
    elseif action == "summary" then
      local mon = selected(screen)
      if mon then
        ensurePartyMon(screen, mon)
        Screens.push(screen.game, "SummaryMenu", mon)
      end
    elseif action == "transfer" then
      quickTransfer(screen)
    elseif action == "release" then
      requestRelease(screen)
    end
  end

  local function updateBoxSwitcher(screen)
    local input = screen.game.input
    if input:wasPressed("left") then
      switchBox(screen, -1)
      screen.status = nil
    elseif input:wasPressed("right") then
      switchBox(screen, 1)
      screen.status = nil
    elseif input:wasPressed("a") or input:wasPressed("b")
        or input:wasPressed("down") or input:wasPressed("select") then
      endBoxSwitcher(screen)
    end
  end

  local function updateActions(screen)
    local input = screen.game.input
    local items = screen.actions
    if input:wasPressed("b") then
      screen.actions = nil
      play(screen, "Press_AB")
    elseif input:wasPressed("up") then
      screen.actionIndex = screen.actionIndex > 1
        and screen.actionIndex - 1 or #items
    elseif input:wasPressed("down") then
      screen.actionIndex = screen.actionIndex < #items
        and screen.actionIndex + 1 or 1
    elseif input:wasPressed("a") then
      play(screen, "Press_AB")
      runAction(screen, items[screen.actionIndex])
    end
  end

  function PC:update(_dt)
    self.blink = ((self.blink or 0) + 1) % 320
	self.marquee = (self.marquee or 0) + 1
    local input = self.game.input
    if self.actions then
      updateActions(self)
      return
    end
    if self.boxSwitching then
      updateBoxSwitcher(self)
      return
    end

    for _, direction in ipairs({ "left", "right", "up", "down" }) do
      if input:wasPressed(direction) then
        self.status = nil
        moveCursor(self, direction)
        return
      end
    end

    if input:wasPressed("a") then
      pickOrDrop(self)
    elseif input:wasPressed("b") then
      if self.held then
        self.held = nil
        self.status = Strings("Move cancelled.")
      else
        self.game.stack:pop()
      end
      play(self, "Press_AB")
    elseif input:wasPressed("select") then
      beginBoxSwitcher(self)
    elseif input:wasPressed("start") and not self.held then
      self.status = nil
      play(self, "Press_AB")
      local items = actionItems(self)
      if #items == 1 then
        self.status = Strings("That slot is empty.")
      else
        self.actions = items
        self.actionIndex = 1
      end
    end
  end

  local function drawBackdrop(layout)
    gray(WHITE)
    love.graphics.rectangle("fill", 0, 0, layout.width, layout.height)
    gray(LIGHT)
    for x = -SCREEN_H, layout.width, 16 do
      love.graphics.line(x, HEADER_H, x + SCREEN_H, FOOTER_Y)
      love.graphics.line(x + SCREEN_H, HEADER_H, x, FOOTER_Y)
    end
  end

  local function drawHeader(screen, layout)
    gray(DARK)
    love.graphics.rectangle("fill", 0, 0, layout.width, HEADER_H)
    gray(LIGHT)
    love.graphics.rectangle("fill", 0, HEADER_H - 2, layout.width, 2)

    local box = Boxes.active(screen.game.save)
    local label = layout.compact
      and Strings("BOX%02d", screen.game.save.currentBox)
      or Strings("BOX%02d %02d/%02d",
        screen.game.save.currentBox, #box, Boxes.CAPACITY)
    local selectorW = math.min(layout.box.w - 2, Font.width(label) + 16)
    local selectorX = layout.compact and layout.box.x + 1
      or math.floor(layout.box.x + (layout.box.w - selectorW) / 2)
    local selectorY = 1
    if screen.boxSwitching then
      gray(BLACK)
      chamfer("fill", selectorX, selectorY, selectorW, 12, 2)
    end

    local function drawArrow(x, left)
      love.graphics.push("all")
      local shader = shaderForInk()
      if shader then love.graphics.setShader(shader) end
      gray(WHITE)
      if left then
        love.graphics.translate(x + 8, 4)
        love.graphics.scale(-1, 1)
        Font.drawCode(Theme.cursor, 0, 0)
      else
        Font.drawCode(Theme.cursor, x, 4)
      end
      love.graphics.pop()
    end
    drawArrow(selectorX, true)
    drawArrow(selectorX + selectorW - 8, false)
    drawCentered(label, selectorX + selectorW / 2, 4,
      selectorW - 16, WHITE)

    if layout.compact then
      drawText(Strings("PARTY"), 4, 4, 40, WHITE)
      drawRight(("%02d/%02d"):format(#box, Boxes.CAPACITY),
        layout.width - 4, 4, 48, WHITE)
    else
      drawCentered(Strings("PARTY"), layout.party.x + layout.party.w / 2,
        4, layout.party.w - 8, WHITE)
      drawCentered(Strings("DETAILS"),
        layout.detail.x + layout.detail.w / 2, 4,
        layout.detail.w - 8, WHITE)
    end
  end

  local function iconEntry(screen, mon)
    local icons = screen.game.data.icons or {}
    local def = screen.game.data.pokemon[mon.species]
    local entry = (icons.bySpecies and icons.bySpecies[mon.species])
      or (def and def.icon)
    if type(entry) ~= "table" then return nil, "" end
    return entry, tostring(entry.image or ""):lower()
  end

  local function isAuthoredIcon(screen, mon)
    local entry, path = iconEntry(screen, mon)
    if not entry then return false end
    local paletteAware = path:find("icons_original", 1, true) ~= nil
    return not paletteAware
      or PartyMenu._uniqueMenuIconsTrueColorWrapped == true
  end

  local function isHgssIcon(screen, mon)
    if not compatibility.hgssSprites then return false end
    local entry, path = iconEntry(screen, mon)
    return entry ~= nil and entry.trueColor == true
      and path:find("assets/icons/", 1, true) ~= nil
      and path:find("hgss", 1, true) ~= nil
  end

  local function fillTrueColorBacking(color, x, y, width, height)
    if not color then return end
    love.graphics.push("all")
    love.graphics.setColor((color[1] or 0) / 255,
      (color[2] or 0) / 255, (color[3] or 0) / 255, 1)
    love.graphics.rectangle("fill", x, y, width, height)
    love.graphics.pop()
  end

  -- Draw through the shared renderer while collecting any full-colour claim
  -- it publishes. The transform is anchored at the requested icon origin so
  -- both enlarged details and a reduced compatibility fallback stay centred.
  local function drawSharedIcon(screen, mon, x, y, animate, scale,
      trueColorRegions)
    scale = tonumber(scale) or 1
    local originalMark = PaletteFX.markTrueColor
    PaletteFX.markTrueColor = function(rx, ry, rw, rh)
      rx, ry, rw, rh = tonumber(rx), tonumber(ry), tonumber(rw), tonumber(rh)
      if not (rx and ry and rw and rh and rw > 0 and rh > 0) then return end
      trueColorRegions[#trueColorRegions + 1] = {
        x = x + (rx - x) * scale,
        y = y + (ry - y) * scale,
        w = rw * scale, h = rh * scale,
      }
    end

    love.graphics.push("all")
    if scale ~= 1 then
      love.graphics.translate(x, y)
      love.graphics.scale(scale, scale)
      love.graphics.translate(-x, -y)
    end
    gray(WHITE)
    local ok, err = pcall(PartyMenu.drawIcon,
      screen.game, mon, x, y,
      animate, animationCounter(screen))
    love.graphics.pop()
    PaletteFX.markTrueColor = originalMark
    if not ok then error(err, 0) end
  end

  -- HGSS menu art is stored as two padded 32x32 frames. Cropping to each
  -- frame's non-transparent bounds prevents the source canvas from covering
  -- neighbouring slots. It also lets us protect only the pixels occupied by
  -- the fitted sprite, instead of restoring a grey 32x32 rectangle afterward.
  local function drawFittedHgssIcon(screen, mon, entry, x, y, animate,
      target, trueColorRegions, background)
    if not (love.image and love.image.newImageData
        and love.graphics.newQuad) then return false end
    local path = Sprites.iconPath(screen.game.data, mon, entry.image, {})
    if type(path) ~= "string" then return false end
    local cached = fittedHgssIcons[path]
    if cached == nil then
      local okData, data = pcall(Assets.imageData, path)
      local okImage, image = pcall(Assets.image, path)
      if not okData or not data or not okImage or not image then
        fittedHgssIcons[path] = false
      else
        local iw, ih = data:getDimensions()
        local rawFrames = {}
        for frame = 0, math.min(1, math.floor(ih / 32) - 1) do
          local minX, minY, maxX, maxY = 32, 32, -1, -1
          for py = 0, math.min(31, ih - frame * 32 - 1) do
            for px = 0, math.min(31, iw - 1) do
              local _, _, _, alpha = data:getPixel(px, frame * 32 + py)
              if (alpha or 0) > 0.01 then
                minX, minY = math.min(minX, px), math.min(minY, py)
                maxX, maxY = math.max(maxX, px), math.max(maxY, py)
              end
            end
          end
          if maxX >= minX and maxY >= minY then
            local runs = {}
            for py = minY, maxY do
              local start
              for px = minX, maxX do
                local _, _, _, alpha = data:getPixel(px, frame * 32 + py)
                local opaque = (alpha or 0) > 0.01
                if opaque and not start then start = px end
                if start and (not opaque or px == maxX) then
                  local finish = opaque and px or px - 1
                  runs[#runs + 1] = { x = start, y = py,
                    w = finish - start + 1 }
                  start = nil
                end
              end
            end
            rawFrames[frame] = { minX = minX, minY = minY,
              maxX = maxX, maxY = maxY, runs = runs }
          end
        end
        -- Preserve the HGSS sheet's internal frame offset. Fitting each
        -- frame to its own alpha bounds independently re-centres away the
        -- common one-pixel bob and makes an animated sheet look static.
        local unionMinX, unionMinY, unionMaxX, unionMaxY
        for _, raw in pairs(rawFrames) do
          unionMinX = unionMinX and math.min(unionMinX, raw.minX) or raw.minX
          unionMinY = unionMinY and math.min(unionMinY, raw.minY) or raw.minY
          unionMaxX = unionMaxX and math.max(unionMaxX, raw.maxX) or raw.maxX
          unionMaxY = unionMaxY and math.max(unionMaxY, raw.maxY) or raw.maxY
        end
        local frames = {}
        if unionMinX then
          for frame, raw in pairs(rawFrames) do
            frames[frame] = {
              x = unionMinX, y = frame * 32 + unionMinY,
              w = unionMaxX - unionMinX + 1,
              h = unionMaxY - unionMinY + 1,
              runs = raw.runs,
            }
          end
        end
        cached = { image = image, iw = iw, ih = ih, frames = frames }
        fittedHgssIcons[path] = cached
      end
    end
    if not cached then return false end

    local alt = false
    if animate then
      local maxHP = mon.stats and mon.stats.hp or 1
      local hpPixels = math.floor((mon.hp or 0) * 48 / math.max(1, maxHP))
      local speed = hpPixels >= 27 and 5 or hpPixels >= 10 and 16 or 32
      alt = animationFrame(screen, speed)
    end
    local bounds = cached.frames[alt and 1 or 0] or cached.frames[0]
    if not bounds then return false end

    local fittedScale = math.min(target / bounds.w, target / bounds.h)
    local drawW, drawH = bounds.w * fittedScale, bounds.h * fittedScale
    local centerX, centerY = x + target / 2, y + target / 2
    local drawX = math.floor(centerX - drawW / 2 + 0.5)
    local drawY = math.floor(centerY - drawH / 2 + 0.5)
    local quad = love.graphics.newQuad(bounds.x, bounds.y,
      bounds.w, bounds.h, cached.iw, cached.ih)
    love.graphics.push("all")
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(cached.image, quad, drawX, drawY, 0,
      fittedScale, fittedScale)
    love.graphics.pop()
    -- Protect only opaque source-pixel runs. Restoring one rectangular fitted
    -- footprint also restores its transparent interior from the unpaletted
    -- canvas, which appears as a darker square on type-coloured panels.
    for _, run in ipairs(bounds.runs or {}) do
      trueColorRegions[#trueColorRegions + 1] = {
        x = drawX + (run.x - bounds.x) * fittedScale,
        y = drawY + (run.y - (bounds.y % 32)) * fittedScale,
        w = math.max(1, run.w * fittedScale),
        h = math.max(1, fittedScale),
      }
    end
    return true
  end

  -- Icon mods may mark their own full-colour pixels from inside the shared
  -- renderer. Hold those claims until the complete PC and its action popup
  -- have been drawn. HGSS receives a dedicated alpha-bound path because its
  -- native 32px contract is intentionally larger than Gen 1's 16px cells.
  local function drawMonIcon(screen, mon, x, y, animate, scale,
      trueColorRegions, background)
    if not mon then return end
    scale = math.max(1, math.floor(tonumber(scale) or 1))
    x, y = math.floor(x), math.floor(y)
    local entry = iconEntry(screen, mon)
    local hgss = isHgssIcon(screen, mon)
    if hgss then
      local target = scale > 1 and 32 or 18
      local zoneX = scale > 1 and x or x - 1
      local zoneY = scale > 1 and y or y - 1
      if drawFittedHgssIcon(screen, mon, entry, zoneX, zoneY,
          animate, target,
          trueColorRegions, background) then
        return
      end

      -- Hosts without readable ImageData still get safe dimensions. Painting
      -- the finished panel colour underneath the reduced source prevents its
      -- full-canvas true-colour claim from becoming a grey backplate.
      fillTrueColorBacking(background, zoneX, zoneY, target, target)
      drawSharedIcon(screen, mon, zoneX, zoneY, animate,
        target / 32, trueColorRegions)
      trueColorRegions[#trueColorRegions + 1] = {
        x = zoneX, y = zoneY, w = target, h = target,
      }
      return
    end

    local authored = isAuthoredIcon(screen, mon)
    if authored then
      fillTrueColorBacking(background, x - scale, y - scale,
        18 * scale, 18 * scale)
    end
    drawSharedIcon(screen, mon, x, y, animate, scale, trueColorRegions)

    if authored then
      trueColorRegions[#trueColorRegions + 1] = {
        x = x - scale, y = y - scale,
        w = 18 * scale, h = 18 * scale,
      }
    end
  end

  local function drawGenderGlyph(mon, x, y, background, trueColorRegions)
    if not (genderExports and type(genderExports.genderOf) == "function"
        and type(genderExports.symbol) == "function") then
      return 0
    end
    local okGender, gender = pcall(genderExports.genderOf, mon)
    if not okGender then return 0 end
    local okSymbol, symbol = pcall(genderExports.symbol, gender)
    if not okSymbol or type(symbol) ~= "string" or symbol == "" then return 0 end

    local color = { 0, 0, 0, 1 }
    if type(genderExports.palette) == "function" then
      local okPalette, exported = pcall(genderExports.palette, gender)
      if okPalette and type(exported) == "table" then color = exported end
    end
    x, y = math.floor(x), math.floor(y)
    fillTrueColorBacking(background, x, y, 8, 8)
    love.graphics.push("all")
    local shader = shaderForInk()
    if shader then love.graphics.setShader(shader) end
    love.graphics.setColor(color[1] or 0, color[2] or 0, color[3] or 0,
      color[4] or 1)
    Font.draw(symbol, x, y)
    love.graphics.pop()
    trueColorRegions[#trueColorRegions + 1] = {
      x = x, y = y, w = 8, h = 8,
    }
    return 9
  end

  local function isHeldOrigin(screen, region, list, index)
    local held = screen.held
    if not held or held.sourceList ~= list or held.sourceIndex ~= index then
      return false
    end
    if region ~= "box" then return true end
    return held.sourceBox == screen.game.save.currentBox
  end

  local function drawGrip(rect)
    gray(WHITE)
    love.graphics.rectangle("fill", rect.x + 2, rect.y + 2, 3, 2)
    love.graphics.rectangle("fill", rect.x + rect.w - 5, rect.y + 2, 3, 2)
    love.graphics.rectangle("fill", rect.x + 2, rect.y + rect.h - 4, 3, 2)
    love.graphics.rectangle("fill", rect.x + rect.w - 5,
      rect.y + rect.h - 4, 3, 2)
  end

  local function drawSlot(screen, layout, region, list, index,
      trueColorRegions)
    local rect = slotRect(layout, region, index)
    local mon = list[index]
    local chosen = screen.region == region and currentIndex(screen) == index
    local origin = isHeldOrigin(screen, region, list, index)

    if chosen then
      gray(BLACK)
      chamfer("fill", rect.x, rect.y, rect.w, rect.h, 2)
      gray(DARK)
      chamfer("fill", rect.x + 2, rect.y + 2,
        rect.w - 4, rect.h - 4, 1)
    elseif mon then
      gray(WHITE)
      love.graphics.rectangle("fill", rect.x + 1, rect.y + 1,
        rect.w - 2, rect.h - 2)
    else
      gray(DARK)
      love.graphics.rectangle("line", rect.x + 2, rect.y + 2,
        math.max(1, rect.w - 5), math.max(1, rect.h - 5))
    end

    if mon then
      local face = chosen
        and colorFromPalette(selectedPalette(screen), 3)
        or colorFromPalette(monPalette(screen, mon), 1)
      if region == "party" and not layout.compact then
        drawMonIcon(screen, mon, rect.x + 2,
          rect.y + math.max(0, math.floor((rect.h - 16) / 2)),
          iconAnimationEnabled(screen) and chosen, 1,
          trueColorRegions, face)
        local ink = chosen and WHITE or BLACK
        drawText(monName(screen, mon), rect.x + 20, rect.y + 2,
          rect.w - 23, ink)
        local levelY = rect.y + rect.h - 10
        local genderWidth = drawGenderGlyph(mon, rect.x + 20, levelY,
          face, trueColorRegions)
        drawText(Strings("L%d", mon.level or 1), rect.x + 20 + genderWidth,
          levelY, rect.w - 23 - genderWidth, ink)
      else
        drawMonIcon(screen, mon,
          rect.x + math.floor((rect.w - 16) / 2),
          rect.y + math.floor((rect.h - 16) / 2),
          iconAnimationEnabled(screen) and chosen, 1,
          trueColorRegions, face)
      end
    end

    if origin then
      gray(chosen and WHITE or DARK)
      love.graphics.line(rect.x + 3, rect.y + 3,
        rect.x + rect.w - 4, rect.y + rect.h - 4)
      love.graphics.line(rect.x + rect.w - 4, rect.y + 3,
        rect.x + 3, rect.y + rect.h - 4)
    end
    if chosen and screen.held then drawGrip(rect) end
  end

  local function drawDetails(screen, layout, trueColorRegions)
    panelFrame(layout.detail, true)
    local mon = screen.held and screen.held.mon or selected(screen)
    if not mon then
      drawCentered(Strings("EMPTY SLOT"),
        layout.detail.x + layout.detail.w / 2,
        layout.detail.y + math.floor((layout.detail.h - 8) / 2),
        layout.detail.w - 10, LIGHT)
      return
    end

    local def = screen.game.data.pokemon[mon.species] or {}
    local name = monName(screen, mon)
    local location = screen.held and Strings("MOVING")
      or (screen.region == "party" and Strings("PARTY")
        or Strings("BOX %02d", screen.game.save.currentBox))
    local detailFace = colorFromPalette(monPalette(screen, mon), 4)

    if layout.compact then
      drawMonIcon(screen, mon, layout.detail.x + 6, layout.detail.y + 6,
        false, 1, trueColorRegions, detailFace)
      drawText(name, layout.detail.x + 27, layout.detail.y + 4,
        math.max(32, layout.detail.w - 92), WHITE)
      local genderWidth = drawGenderGlyph(mon, layout.detail.x + 27,
        layout.detail.y + 15, detailFace, trueColorRegions)
      drawText(Strings("LV%d  %s", mon.level or 1, location),
        layout.detail.x + 27 + genderWidth, layout.detail.y + 15,
        layout.detail.w - 34 - genderWidth, LIGHT)
      if mon.stats and mon.hp then
        drawRight(Strings("HP %d/%d", mon.hp, mon.stats.hp),
          layout.detail.x + layout.detail.w - 5, layout.detail.y + 4,
          72, WHITE)
      end
      return
    end

    local iconScale = layout.detail.w >= 76 and 2 or 1
    local iconSize = 16 * iconScale
    drawMonIcon(screen, mon,
      layout.detail.x + math.floor((layout.detail.w - iconSize) / 2),
      layout.detail.y + 8, false, iconScale,
      trueColorRegions, detailFace)
    local infoY = layout.detail.y + 14 + iconSize
    drawCentered(name, layout.detail.x + layout.detail.w / 2,
      infoY, layout.detail.w - 10, WHITE)
    local levelText = Strings("LV%d", mon.level or 1)
    local levelWidth = Font.width(levelText)
    local genderWidth = genderExports and 9 or 0
    local levelX = math.floor(layout.detail.x +
      (layout.detail.w - levelWidth - genderWidth) / 2)
    genderWidth = drawGenderGlyph(mon, levelX, infoY + 11,
      detailFace, trueColorRegions)
    drawText(levelText, levelX + genderWidth, infoY + 11,
      levelWidth, LIGHT)
    local types = def.types or {}
    local typeText = tostring(types[1] or "---")
    if types[2] then typeText = typeText .. "/" .. tostring(types[2]) end
    drawCentered(typeText, layout.detail.x + layout.detail.w / 2,
      infoY + 23, layout.detail.w - 10, LIGHT)
    if mon.stats and mon.hp then
      local hpText = layout.detail.w >= 72
        and Strings("HP %d/%d", mon.hp, mon.stats.hp)
        or Strings("HP %d", mon.hp)
      drawCentered(hpText,
        layout.detail.x + layout.detail.w / 2, infoY + 35,
        layout.detail.w - 10, WHITE)
    end
    drawCentered(location, layout.detail.x + layout.detail.w / 2,
      layout.detail.y + layout.detail.h - 13,
      layout.detail.w - 10, LIGHT)
  end

  local function drawFooter(screen, layout)
    gray(DARK)
    love.graphics.rectangle("fill", 0, FOOTER_Y, layout.width, 9)
    local message = screen.status
    if not message then
      if screen.held then
        message = layout.compact and Strings("A PLACE  B CANCEL")
          or Strings("A PLACE B CANCEL SEL BOXES")
      else
        message = layout.compact and Strings("[A] MOVE   [SELECT] BOX")
		  or Strings("[A] MOVE   [START] OPTIONS   [SELECT] BOXES")
      end
    end
    if screen.boxSwitching then
      message = layout.compact and Strings("ARROWS BOX A DONE")
        or Strings("LEFT RIGHT BOX  A DONE")
    end
	
	local footerX = 4
	local footerW = layout.width - 8
	local textW = Font.width(message)

	if textW <= footerW then
	  drawCentered(message, layout.width / 2, FOOTER_Y + 1,
		footerW, WHITE)
	else
	  local gap = 24
	  local stride = textW + gap
	  local offset = math.floor((screen.marquee or 0) / 8) % stride

	  local sx, sy, sw, sh = love.graphics.getScissor()
	  love.graphics.setScissor(footerX, FOOTER_Y, footerW, 9)

	  local x = footerX - offset

	  while x < footerX + footerW do
		drawText(message, x, FOOTER_Y + 1, textW, WHITE)
		x = x + stride
	  end

	  if sx then
		love.graphics.setScissor(sx, sy, sw, sh)
	  else
		love.graphics.setScissor()
	end
end
end

  local function actionGeometry(screen, layout)
    local rowH = 12
    local width = math.min(112, math.max(88, math.floor(layout.width * 0.42)))
    local height = #screen.actions * rowH + 6
    local x, y = layout.width - width - 4, FOOTER_Y - height - 2
    return x, y, width, height, rowH
  end

  local function drawActions(screen, layout)
    if not screen.actions then return end
    local x, y, width, height, rowH = actionGeometry(screen, layout)
    local panel = { x = x, y = y, w = width, h = height }
    panelFrame(panel, false)

    for index, entry in ipairs(screen.actions) do
      local rowY = y + 3 + (index - 1) * rowH
      local chosen = index == screen.actionIndex
      if chosen then
        gray(BLACK)
        chamfer("fill", x + 3, rowY, width - 6, rowH - 1, 2)
      end
      drawText(entry.label, x + 12, rowY + 2, width - 18,
        chosen and WHITE or BLACK)
      if chosen then
        gray(WHITE)
        love.graphics.rectangle("fill", x + 6, rowY + 4, 3, 3)
      end
    end
  end

  -- PaletteFX restores full-colour regions from the finished UI canvas. Split
  -- any region intersecting the action card so its later restore cannot paint
  -- an underlying icon or gender cell back over the popup.
  local function markTrueColorOutside(rect, cutout)
    if not cutout then
      PaletteFX.markTrueColor(rect.x, rect.y, rect.w, rect.h)
      return
    end
    local x1, y1 = rect.x, rect.y
    local x2, y2 = x1 + rect.w, y1 + rect.h
    local cx1, cy1 = cutout.x, cutout.y
    local cx2, cy2 = cx1 + cutout.w, cy1 + cutout.h
    local ix1, iy1 = math.max(x1, cx1), math.max(y1, cy1)
    local ix2, iy2 = math.min(x2, cx2), math.min(y2, cy2)
    if ix1 >= ix2 or iy1 >= iy2 then
      PaletteFX.markTrueColor(x1, y1, rect.w, rect.h)
      return
    end
    if y1 < iy1 then
      PaletteFX.markTrueColor(x1, y1, rect.w, iy1 - y1)
    end
    if iy2 < y2 then
      PaletteFX.markTrueColor(x1, iy2, rect.w, y2 - iy2)
    end
    if x1 < ix1 then
      PaletteFX.markTrueColor(x1, iy1, ix1 - x1, iy2 - iy1)
    end
    if ix2 < x2 then
      PaletteFX.markTrueColor(ix2, iy1, x2 - ix2, iy2 - iy1)
    end
  end

  function PC:draw()
    local layout = layoutFor(self)
    local trueColorRegions = {}
    drawBackdrop(layout)
    drawHeader(self, layout)
    panelFrame(layout.party, false)
    panelFrame(layout.box, false)

    local party = self.game.save.party
    local box = Boxes.active(self.game.save)
    for index = 1, Party.MAX do
      drawSlot(self, layout, "party", party, index, trueColorRegions)
    end
    for index = 1, Boxes.CAPACITY do
      drawSlot(self, layout, "box", box, index, trueColorRegions)
    end
    drawDetails(self, layout, trueColorRegions)
    drawFooter(self, layout)
    drawActions(self, layout)

    local modalCutout
    if self.actions then
      local x, y, width, height = actionGeometry(self, layout)
      modalCutout = { x = x, y = y, w = width + 2, h = height + 2 }
    end
    for _, rect in ipairs(trueColorRegions) do
      markTrueColorOutside(rect, modalCutout)
    end
    gray(WHITE)
  end

  function PC:sgbPalettes(game)
    local data = game and game.data
    if not data then return nil end
    local layout = layoutFor(self)
    local base = PaletteFX.pal(data, "BLUEMON")
      or PaletteFX.pal(data, "MEWMON")
    if not base then return nil end
    local zones = {
      { colors = base, x = 0, y = 0, w = layout.width, h = SCREEN_H },
    }
    local header = base
    local partyPal = PaletteFX.pal(data, "GREENMON") or base
    local boxPal = PaletteFX.pal(data, "CYANMON") or base
    zones[#zones + 1] = {
      colors = header, x = 0, y = 0, w = layout.width, h = HEADER_H,
    }
    zones[#zones + 1] = {
      colors = partyPal, x = layout.party.x, y = layout.party.y,
      w = layout.party.w, h = layout.party.h,
    }
    zones[#zones + 1] = {
      colors = boxPal, x = layout.box.x, y = layout.box.y,
      w = layout.box.w, h = layout.box.h,
    }

    local party = self.game.save.party
    local box = Boxes.active(self.game.save)
    for index, mon in ipairs(party) do
      local rect = slotRect(layout, "party", index)
      zones[#zones + 1] = {
        colors = monPalette(self, mon), x = rect.x, y = rect.y,
        w = rect.w, h = rect.h,
      }
    end
    for index, mon in ipairs(box) do
      local rect = slotRect(layout, "box", index)
      zones[#zones + 1] = {
        colors = monPalette(self, mon), x = rect.x, y = rect.y,
        w = rect.w, h = rect.h,
      }
    end
    local detailMon = self.held and self.held.mon or selected(self)
    if detailMon then
      zones[#zones + 1] = {
        colors = monPalette(self, detailMon),
        x = layout.detail.x, y = layout.detail.y,
        w = layout.detail.w, h = layout.detail.h,
      }
    end
    local selectedPal = PaletteFX.pal(data, "YELLOWMON") or header
    local rect = slotRect(layout, self.region, currentIndex(self))
    zones[#zones + 1] = {
      colors = selectedPal, x = rect.x, y = rect.y, w = rect.w, h = rect.h,
    }
    zones[#zones + 1] = {
      colors = header, x = 0, y = FOOTER_Y, w = layout.width, h = 9,
    }
    if self.actions then
      local x, y, width, height = actionGeometry(self, layout)
      zones[#zones + 1] = {
        colors = base, x = x, y = y, w = width, h = height,
      }
    end
    return zones
  end

  function PC:uiSize()
    return responsiveWidth(), SCREEN_H
  end

  function PC:isWideBattleLayout()
    return true
  end

  -- Named helpers are intentionally exposed for compatibility tests and for
  -- companion mods that want to add non-destructive PC shortcuts.
  function PC:modernPCSelected()
    return selected(self)
  end

  function PC:modernPCPickOrDrop()
    return pickOrDrop(self)
  end

  function PC:modernPCSwitchBox(delta)
    return switchBox(self, delta)
  end

  function PC:modernPCQuickTransfer()
    return quickTransfer(self)
  end

  function PC:modernPCRequestRelease()
    return requestRelease(self)
  end

  function PC:modernPCLayoutInfo()
    return layoutFor(self)
  end

  return {
    new = function(game)
      Boxes.ensure(game.save)
      game.save.party = game.save.party or {}
      return setmetatable({
        game = game,
        region = "box",
        partyIndex = math.max(1, math.min(Party.MAX,
          game.partyMenuSavedIndex or 1)),
        boxIndex = 1,
        blink = 0,
        held = nil,
        boxSwitching = false,
        boxSwitchReturnRegion = nil,
        actions = nil,
        actionIndex = 1,
        status = nil,
        modernPCUI = true,
        modernPCLayout = "party-and-box",
        holdsUIAnchors = true,
      }, PC)
    end,
  }
end

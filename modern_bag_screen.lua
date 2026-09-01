-- Pocket-based presentation for src/ui/BagMenu.
--
-- The built-in BagMenu already owns a large and delicate behavior surface:
-- item targeting, battle turns, field actions, toss confirmation, scripted
-- tutorial input and several screens opened after item use. This module wraps
-- that controller instead of duplicating it. Only the visible list, drawing,
-- left/right pocket navigation and filtered-list reordering live here.
return function(mod, compatibility, menuColors, useStockOgMenuPalette,
    menuPaperPalette)
  compatibility = compatibility or {}
  local BagMenu = require("src.ui.BagMenu")
  local Bag = require("src.inventory.Bag")
  local Assets = require("src.render.Assets")
  local Font = require("src.render.Font")
  local ItemEffects = require("src.inventory.ItemEffects")
  local PaletteFX = require("src.render.PaletteFX")
  local Strings = require("src.core.Strings")
  local Theme = require("src.ui.Theme")
  local TouchControls = require("src.core.TouchControls")

  local SCREEN_W = 160
  local SCREEN_H = 144
  local HEADER_H = 16
  local TABS_H = 18
  local FOOTER_H = 9
  local PORTRAIT_MIN_H = 224
  local PORTRAIT_MAX_H = 400
  local ROWS = 6
  local ROW_H = 13

  local WHITE = 1
  local LIGHT = 170 / 255
  local DARK = 85 / 255
  local BLACK = 0

  local function classicSkin()
    return mod.options:get("skin") == "classic_pocket"
  end

  local POCKETS = {
    { key = "all", label = "ALL ITEMS", short = "ALL", palette = "BLUEMON",
      blurb = Strings.source("Everything you are carrying.") },
    { key = "items", label = "ITEMS", short = "ITEMS", palette = "BROWNMON",
      blurb = Strings.source("Useful items for your journey.") },
    { key = "medicine", label = "MEDICINE", short = "MED", palette = "GREENMON",
      blurb = Strings.source("Items that help your POKéMON.") },
    { key = "balls", label = "POKé BALLS", short = "BALLS", palette = "REDMON",
      blurb = Strings.source("Devices for catching wild POKéMON.") },
    { key = "machines", label = "TMs/HMs", short = "TMs", palette = "PURPLEMON",
      blurb = Strings.source("Machines that teach new moves.") },
    { key = "key", label = "KEY ITEMS", short = "KEY", palette = "CYANMON",
      blurb = Strings.source("Important items for your adventure.") },
  }

  -- Kanto Reforged exposes these five pockets on its public Bag controller.
  -- The source id is retained because its controller uses "tmhm", while the
  -- Modern Bag presentation calls the same visual category "machines".
  local KANTO_POCKETS = {
    { key = "items", source = "items", label = "ITEMS", short = "ITEMS",
      palette = "BROWNMON",
      blurb = Strings.source("Useful and held items for your journey.") },
    { key = "balls", source = "balls", label = "POKé BALLS", short = "BALLS",
      palette = "REDMON",
      blurb = Strings.source("Devices for catching wild POKéMON.") },
    { key = "key", source = "key", label = "KEY ITEMS", short = "KEY",
      palette = "CYANMON",
      blurb = Strings.source("Important items for your adventure.") },
    { key = "machines", source = "tmhm", label = "TMs & HMs", short = "TMs",
      palette = "PURPLEMON",
      blurb = Strings.source("Machines that teach new moves.") },
    { key = "berries", source = "berries", label = "BERRIES", short = "BERRY",
      palette = "GREENMON",
      blurb = Strings.source("Berries that POKéMON can use or hold.") },
  }

  -- The reference skin uses compact, title-case labels in its rail rather
  -- than the all-caps names used by the modern header and tabs.
  local CLASSIC_POCKET_LABELS = {
    all = "All",
    items = "Items",
    medicine = "Meds",
    balls = "Balls",
    machines = "TMs",
    key = "Key",
    berries = "Berries",
  }

  -- The extracted reference backpack has five real compartments. All is a
  -- combined view; the remaining five categories each own one sprite region.
  -- Battle enhancers stay in Items so the navigation and artwork are 1:1.
  local CLASSIC_BAG_REGIONS = {
    all = "all",
    items = "items",
    medicine = "medicine",
    balls = "balls",
    machines = "machines",
    key = "key",
    -- Kanto's Berry pocket uses the backpack's medicine compartment; both
    -- configurations therefore keep a five-compartment sprite.
    berries = "medicine",
  }
  local CLASSIC_BAG_ASSET = mod.path .. "/assets/classic_bag_pockets.png"

  local MEDICINE = {
    POTION = true, SUPER_POTION = true, HYPER_POTION = true,
    MAX_POTION = true, FULL_RESTORE = true, FRESH_WATER = true,
    SODA_POP = true, LEMONADE = true, ANTIDOTE = true,
    BURN_HEAL = true, ICE_HEAL = true, AWAKENING = true,
    PARLYZ_HEAL = true, FULL_HEAL = true, REVIVE = true,
    MAX_REVIVE = true, RARE_CANDY = true, HP_UP = true,
    PROTEIN = true, IRON = true, CARBOS = true, CALCIUM = true,
    PP_UP = true, ETHER = true, MAX_ETHER = true,
    ELIXER = true, MAX_ELIXER = true,
  }

  local BERRIES = {
    BERRY = true, CHERI_BERRY = true, CHESTO_BERRY = true,
    PECHA_BERRY = true, RAWST_BERRY = true, ASPEAR_BERRY = true,
    PERSIM_BERRY = true, LUM_BERRY = true,
  }

  local DESCRIPTIONS = {
    POTION = Strings.source("Restores 20 HP to one POKéMON."),
    SUPER_POTION = Strings.source("Restores 50 HP to one POKéMON."),
    HYPER_POTION = Strings.source("Restores 200 HP to one POKéMON."),
    MAX_POTION = Strings.source("Fully restores one POKéMON's HP."),
    FULL_RESTORE = Strings.source("Fully restores HP and cures status."),
    FRESH_WATER = Strings.source("A refreshing drink that restores 50 HP."),
    SODA_POP = Strings.source("A fizzy drink that restores 60 HP."),
    LEMONADE = Strings.source("A sweet drink that restores 80 HP."),
    ANTIDOTE = Strings.source("Cures a poisoned POKéMON."),
    BURN_HEAL = Strings.source("Cures a burned POKéMON."),
    ICE_HEAL = Strings.source("Defrosts a frozen POKéMON."),
    AWAKENING = Strings.source("Wakes a sleeping POKéMON."),
    PARLYZ_HEAL = Strings.source("Cures a paralyzed POKéMON."),
    FULL_HEAL = Strings.source("Cures all status conditions."),
    REVIVE = Strings.source("Revives a fainted POKéMON with half HP."),
    MAX_REVIVE = Strings.source("Revives a fainted POKéMON with full HP."),
    RARE_CANDY = Strings.source("Raises one POKéMON by one level."),
    PP_UP = Strings.source("Raises the maximum PP of one move."),
    ETHER = Strings.source("Restores 10 PP to one move."),
    MAX_ETHER = Strings.source("Fully restores the PP of one move."),
    ELIXER = Strings.source("Restores 10 PP to every move."),
    MAX_ELIXER = Strings.source("Fully restores the PP of every move."),
    ESCAPE_ROPE = Strings.source("Returns you to the last POKéMON Center."),
    REPEL = Strings.source("Keeps weak wild POKéMON away briefly."),
    SUPER_REPEL = Strings.source("Keeps weak wild POKéMON away longer."),
    MAX_REPEL = Strings.source("Keeps weak wild POKéMON away the longest."),
    FIRE_STONE = Strings.source("A peculiar stone that evolves some POKéMON."),
    WATER_STONE = Strings.source("A peculiar stone that evolves some POKéMON."),
    THUNDER_STONE = Strings.source("A peculiar stone that evolves some POKéMON."),
    LEAF_STONE = Strings.source("A peculiar stone that evolves some POKéMON."),
    MOON_STONE = Strings.source("A peculiar stone that evolves some POKéMON."),
    NUGGET = Strings.source("A solid gold nugget that sells for a high price."),
    POKE_DOLL = Strings.source("A doll that can help you escape a wild battle."),
    BICYCLE = Strings.source("A folding bicycle that is faster than walking."),
    TOWN_MAP = Strings.source("A convenient map of the Kanto region."),
    ITEMFINDER = Strings.source("Checks the area for hidden items."),
    POKE_FLUTE = Strings.source("A flute with a melody that wakes sleepers."),
    OLD_ROD = Strings.source("Use it by water to fish for POKéMON."),
    GOOD_ROD = Strings.source("A good rod for fishing up POKéMON."),
    SUPER_ROD = Strings.source("The best rod for fishing up POKéMON."),
  }

  local inkShader -- false when shaders are unavailable
  local classicLabelFont -- false when direct TTF labels are unavailable
  local classicBagSprites -- false when the source sprite cannot be loaded

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

  local function drawTextRight(text, right, y, maxWidth, shade)
    text = fitText(text, maxWidth)
    local width = Font.width(text)
    drawText(text, right - width, y, maxWidth, shade)
    return width
  end

  local function classicRailLabel(text, x, y, width, height)
    text = tostring(text or "")
    if classicLabelFont == nil then
      if not love.graphics.newFont then
        classicLabelFont = false
      else
        local ok, face = pcall(love.graphics.newFont,
          Font.PLAINPIXEL, 10, "mono")
        if ok and face then
          if face.setFilter then
            pcall(face.setFilter, face, "nearest", "nearest")
          end
          classicLabelFont = face
        else
          classicLabelFont = false
        end
      end
    end

    local face = classicLabelFont or nil
    if not face or not love.graphics.print then
      local fallback = fitText(text, width)
      drawText(fallback, x + math.floor((width - Font.width(fallback)) / 2),
        y + math.floor((height - 8) / 2), width, WHITE)
      return fallback
    end

    local original = text
    local spans = Font.split(original)
    local count = #spans
    while count > 1 and face:getWidth(text) > width do
      count = count - 1
      text = original:sub(1, spans[count].to) .. "."
    end
    love.graphics.push("all")
    local shader = shaderForInk()
    if shader then
      love.graphics.setShader(shader)
      gray(WHITE)
    else
      gray(BLACK)
    end
    love.graphics.setFont(face)
    love.graphics.print(text,
      math.floor(x + (width - face:getWidth(text)) / 2),
      math.floor(y + (height - face:getHeight()) / 2))
    love.graphics.pop()
    return text
  end

  local function drawCode(code, x, y, shade)
    love.graphics.push("all")
    local shader = shaderForInk()
    if shader then
      love.graphics.setShader(shader)
      gray(shade == nil and WHITE or shade)
    else
      gray(BLACK)
    end
    Font.drawCode(code, math.floor(x), math.floor(y))
    love.graphics.pop()
  end

  local function wrappedLines(text, maxWidth, maxLines)
    local lines, current = {}, ""
    for word in tostring(text or ""):gmatch("%S+") do
      local candidate = current == "" and word or (current .. " " .. word)
      if current ~= "" and Font.width(candidate) > maxWidth then
        lines[#lines + 1] = fitText(current, maxWidth)
        current = word
        if #lines >= maxLines then break end
      else
        current = candidate
      end
    end
    if #lines < maxLines and current ~= "" then
      lines[#lines + 1] = fitText(current, maxWidth)
    end
    return lines
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

  -- Symmetric hard-pixel rounded rectangle.  Three stacked rectangles form
  -- identical two-pixel steps at all four corners without antialiasing.
  local function pixelRoundFill(x, y, width, height)
    x, y = math.floor(x), math.floor(y)
    width, height = math.floor(width), math.floor(height)
    love.graphics.rectangle("fill", x + 2, y, width - 4, height)
    love.graphics.rectangle("fill", x + 1, y + 1, width - 2, height - 2)
    love.graphics.rectangle("fill", x, y + 2, width, height - 4)
  end

  local function displayPixels()
    local width, height
    if love.graphics.getPixelDimensions then
      width, height = love.graphics.getPixelDimensions()
    else
      width, height = love.graphics.getDimensions()
    end
    return tonumber(width) or 160, tonumber(height) or SCREEN_H
  end

  -- The touch pad is painted after the game canvas. On portrait devices its
  -- controls can occupy a large lower section of the drawable, so treating
  -- that covered area as useful Bag height produces an unnecessarily tall
  -- canvas and forces the visible Bag above it to a smaller integer scale.
  local function portraitControlsTop(pixelWidth, pixelHeight)
    if pixelHeight <= pixelWidth then return nil end
    local okVisible, visible = pcall(TouchControls.visible, TouchControls)
    if not okVisible or not visible then return nil end
    local okLayout, controls = pcall(TouchControls.layout, TouchControls)
    if not okLayout or type(controls) ~= "table" then return nil end
    local _, unitHeight = love.graphics.getDimensions()
    unitHeight = tonumber(unitHeight) or pixelHeight
    if unitHeight <= 0 then return nil end
    local dpiY = pixelHeight / unitHeight
    local top
    for _, name in ipairs({ "dpad", "a", "b", "start", "select" }) do
      local zone = controls[name]
      if type(zone) == "table" and tonumber(zone.cy)
          and tonumber(zone.w) then
        -- TouchControls' backing disc is the first visible pixel of a
        -- control, at 0.58 times its configured width above the centre.
        local y = (zone.cy - zone.w * 0.58) * dpiY
        top = top and math.min(top, y) or y
      end
    end
    if not top then return nil end
    return math.max(SCREEN_H, math.floor(top))
  end

  local function responsiveSize()
    local width, height = displayPixels()
    local portraitWindow = height > width

    -- A wide window keeps the original 144px-tall responsive surface. A
    -- phone in portrait needs the inverse treatment: lock the readable
    -- 160px width, then use the vertical pixels available at that same
    -- integer scale. This avoids both a postage-stamp Bag and resampled text.
    local portraitScale = math.max(1, math.floor(width / 160))
    local portraitHeight = math.min(PORTRAIT_MAX_H,
      math.floor(height / portraitScale))
    if portraitWindow and portraitHeight >= PORTRAIT_MIN_H then
      return 160, portraitHeight
    end

    local scale = math.max(1, math.floor(height / SCREEN_H))
    return math.max(160, math.min(400, math.floor(width / scale))),
      math.max(SCREEN_H, math.floor(height / scale))
  end

  -- FAITHFUL RATIO owns the shape of the complete UI surface. On desktop the
  -- option also resizes the window, so responsiveSize happens to arrive at
  -- 160x144. Phones cannot resize their window, however: the renderer locks
  -- a 160x144 viewport inside the physical display instead. Reading only the
  -- drawable dimensions there made the Bag request a tall 160x400 canvas and
  -- defeated that lock (most visibly alongside Useful Bag).
  local function faithfulRatioEnabled(menu)
    local options = menu and menu.game and menu.game.save
      and menu.game.save.options
    return (tonumber(options and options.faithfulRes) or 0) > 0
  end

  -- Useful Bag calls the same presentation choice FULLSCREEN BAG MENUS.
  -- OFF means its native Game Boy-sized pop-out, so Modern Bag must not
  -- replace that choice with its tall-phone canvas merely because it owns the
  -- shared BagMenu presentation record.
  local function usefulBagNativeMenus(menu)
    if not compatibility.usefulBag then return false end
    local game = menu and menu.game
    local loaderOptions = game and game.mods and game.mods.modOptions
    local savedOptions = game and game.save and game.save.options
      and game.save.options.modOptions
    local bucket = loaderOptions and loaderOptions.useful_bag
    local value = bucket and bucket.fullscreen_menu
    if value == nil then
      bucket = savedOptions and savedOptions.useful_bag
      value = bucket and bucket.fullscreen_menu
    end
    return value == false
  end

  local function nativeViewportRequested(menu)
    return faithfulRatioEnabled(menu) or usefulBagNativeMenus(menu)
  end

  local function confineNativeViewport(menu)
    if not nativeViewportRequested(menu) then return end
    local renderer = menu and menu.game and menu.game.renderer
    if renderer then
      -- Game:draw may inherit BATTLE SIZE = FILL from a battle underneath the
      -- Bag. Renderer:endFrame applies that after fitScale, which stretches a
      -- correctly-sized 160x144 canvas back over the whole phone. The Bag is
      -- a native pop-out in this mode, so the later fill override must not win.
      renderer.uiFill = false
    end
  end

  local function uiSize(menu)
    if nativeViewportRequested(menu) then return SCREEN_W, SCREEN_H end
    return responsiveSize()
  end

  local function layoutFor(menu)
    local nativeViewport = nativeViewportRequested(menu)
    local width, height = uiSize(menu)
    local renderer = menu and menu.game and menu.game.renderer
    -- Renderer:uiSize still describes the previous frame while an option or
    -- state is changing. Never let that stale responsive size override the
    -- explicit faithful-ratio request.
    if not nativeViewport and renderer and renderer.uiSize then
      local rendererW, rendererH = renderer:uiSize()
      width, height = rendererW or width, rendererH or height
    end
    width = math.max(160, math.floor(width))
    height = math.max(SCREEN_H, math.floor(height))
    local canvasHeight = height

    -- Keep the full responsive canvas—and therefore its larger integer
    -- scale—but end the actual Bag composition above visible touch controls.
    -- The unused lower canvas becomes a black control bed instead of making
    -- the Bag narrower or letting controls cover its description/footer.
    local pixelWidth, pixelHeight = displayPixels()
    local controlsTop = portraitControlsTop(pixelWidth, pixelHeight)
    if controlsTop then
      local scale = math.max(1, math.floor(math.min(
        pixelWidth / width, pixelHeight / canvasHeight)))
      local offsetY = math.max(0,
        math.floor((pixelHeight - canvasHeight * scale) / 2))
      local usableHeight = math.floor((controlsTop - offsetY) / scale)
      if usableHeight >= PORTRAIT_MIN_H then
        height = math.min(height, usableHeight)
      end
    end
    local wide = width >= 196
    local stacked = not wide and height >= PORTRAIT_MIN_H

    if classicSkin() then
      local headerH = stacked and 18 or 14
      local detailH = stacked and 84 or 40
      local detailY = height - detailH
      local topRail = stacked
      local railW = topRail and width
        or (wide and math.max(56, math.floor(width * 0.25)) or 48)
      local railH = topRail and 48 or (detailY - headerH)
      local listX = topRail and 0 or railW
      local listY = topRail and (headerH + railH) or headerH
      local listW = topRail and width or (width - railW)
      local listH = detailY - listY
      local rows = math.max(4, math.min(stacked and 10 or 6,
        math.floor((listH - 5) / ROW_H)))
      return {
        skin = "classic_pocket",
        width = width, height = height, canvasHeight = canvasHeight,
        wide = wide, stacked = stacked, topRail = topRail,
        showDetails = true,
        headerH = headerH, tabsY = headerH, tabsH = 0,
        contentY = listY, footerY = detailY, footerH = detailH,
        rows = rows,
        railX = 0, railY = headerH, railW = railW,
        railH = railH,
        listX = listX, listY = listY,
        listW = listW, listH = listH,
        headerAccentX = topRail and 48 or listX,
        headerAccentW = topRail and 64 or listW,
        detailX = 0, detailY = detailY,
        detailW = width, detailH = detailH,
      }
    end

    local headerH = stacked and 24 or HEADER_H
    local tabsY = headerH
    local contentY = tabsY + TABS_H
    local expandedFooter = menu and menu.modernBagPrompt
    local footerH = stacked and 20 or (expandedFooter and 16 or FOOTER_H)
    local footerY = height - footerH
    local listY = contentY + (wide and 4 or 3)

    if stacked then
      local detailMinH = 82
      local rows = math.floor((footerY - listY - detailMinH - 12) / ROW_H)
      rows = math.max(4, math.min(10, rows))
      local listH = rows * ROW_H + 8
      local detailY = listY + listH + 4
      return {
        width = width, height = height, canvasHeight = canvasHeight,
        wide = false, stacked = true, showDetails = true,
        headerH = headerH, tabsY = tabsY, tabsH = TABS_H,
        contentY = contentY, footerY = footerY, footerH = footerH,
        rows = rows,
        listX = 4, listY = listY, listW = width - 12, listH = listH,
        detailX = 4, detailY = detailY,
        detailW = width - 8, detailH = footerY - detailY - 3,
      }
    end

    local listColumnW = wide and math.floor(width * 0.54) or width - 8
    listColumnW = math.max(96, listColumnW)
    local rows = math.max(4, math.floor((footerY - listY - 8) / ROW_H))
    return {
      width = width, height = height, canvasHeight = canvasHeight,
      wide = wide, stacked = false, showDetails = wide,
      headerH = headerH, tabsY = tabsY, tabsH = TABS_H,
      contentY = contentY, footerY = footerY, footerH = footerH,
      rows = rows,
      listX = 4,
      listY = listY,
      listW = listColumnW - 4,
      listH = footerY - contentY - 6,
      detailX = listColumnW + 4,
      detailY = listY,
      detailW = width - listColumnW - 8,
      detailH = footerY - contentY - 6,
    }
  end

  local function normalizedPocket(value)
    value = tostring(value or ""):lower():gsub("[^a-z]", "")
    local aliases = {
      item = "items", items = "items", other = "items",
      medicine = "medicine", medicines = "medicine", healing = "medicine",
      ball = "balls", balls = "balls", pokeballs = "balls",
      battle = "battle", battleitems = "battle",
      tm = "machines", tms = "machines", hm = "machines",
      hms = "machines", machine = "machines", machines = "machines",
      key = "key", keyitem = "key", keyitems = "key",
      berry = "berries", berries = "berries",
    }
    return aliases[value]
  end

  local function categoryFor(game, id)
    if not id then return "items" end
    local def = game.data.items[id] or {}
    local explicit = normalizedPocket(def.bagPocket or def.pocket)
    if explicit then return explicit end
    if BERRIES[id] or def.holdEffect == "berry"
        or def.holdEffect == "berry_status" then
      return "berries"
    end
    if ItemEffects.isBall(id) or def.ball then return "balls" end
    if def.machine then return "machines" end
    if def.keyItem then return "key" end
    if MEDICINE[id] then return "medicine" end
    return "items"
  end

  local function pocketsFor(menu)
    return menu.modernBagPockets or POCKETS
  end

  local function pocketFor(menu)
    local pockets = pocketsFor(menu)
    return pockets[menu.modernBagPocket or 1] or pockets[1] or POCKETS[1]
  end

  local function syncExternalPocketIndex(menu)
    if not menu.modernBagExternalController then return end
    local sourceIds = menu.__pocketIds or {}
    local source = sourceIds[menu.__pocketIndex or 1]
    local pockets = pocketsFor(menu)
    for index, pocket in ipairs(pockets) do
      if pocket.source == source or pocket.key == source then
        menu.modernBagPocket = index
        return
      end
    end
    menu.modernBagPocket = math.max(1,
      math.min(menu.__pocketIndex or 1, #pockets))
  end

  local function listConfig(menu)
    return menu.modernBagListConfig
  end

  local function itemStore(menu)
    local config = listConfig(menu)
    if config and type(config.store) == "function" then
      return config.store(menu) or {}
    end
    return menu.game.save.inventory
  end

  local function orderedIds(menu, store)
    local config = listConfig(menu)
    if config and type(config.order) == "function" then
      return config.order(menu, store) or {}
    end
    -- Kanto filters Bag.order globally while one pocket is open. Counts and
    -- change detection need the complete order, not only the active pocket.
    if menu.modernBagExternalController then
      local order = menu.game.save.bagOrder
      if type(order) == "table" then return order end
      local ids = {}
      for id in pairs(store or {}) do ids[#ids + 1] = id end
      table.sort(ids)
      return ids
    end
    return Bag.order(menu.game.save)
  end

  local function included(menu, id)
    local config = listConfig(menu)
    return not (config and type(config.filter) == "function")
      or config.filter(menu, id)
  end

  local function makeRows(menu, pocketKey)
    local rows = {}
    local store = itemStore(menu)
    for _, id in ipairs(orderedIds(menu, store)) do
      if included(menu, id)
          and (pocketKey == "all" or categoryFor(menu.game, id) == pocketKey) then
        local def = menu.game.data.items[id]
        rows[#rows + 1] = {
          value = id,
          label = def and def.name or id,
          right = "x" .. tostring(store[id] or 0),
        }
      end
    end
    return rows
  end

  local function inventorySignature(menu)
    local parts = {}
    local store = itemStore(menu)
    for _, id in ipairs(orderedIds(menu, store)) do
      if included(menu, id) then
        parts[#parts + 1] = id .. ":" .. tostring(store[id])
      end
    end
    return table.concat(parts, "|")
  end

  local function clampList(menu)
    local count = #menu.items
    local rows = math.max(1, menu.rows or ROWS)
    menu.index = math.max(1, math.min(menu.index or 1, math.max(1, count)))
    menu.scroll = math.max(0, math.min(menu.scroll or 0,
      math.max(0, count - rows)))
    if menu.index - menu.scroll > rows then
      menu.scroll = menu.index - rows
    elseif menu.index - menu.scroll < 1 then
      menu.scroll = menu.index - 1
    end
  end

  local function rebuildPocket(menu, preserveId)
    if menu.modernBagExternalController then
      local api = menu.gen1ModernUi
      if api and type(api.switchPocket) == "function" then
        api:switchPocket(0)
      end
      syncExternalPocketIndex(menu)
      if preserveId then
        for index, item in ipairs(menu.items or {}) do
          if item.value == preserveId then
            menu.index = index
            break
          end
        end
      end
      clampList(menu)
      menu.modernBagInventorySignature = inventorySignature(menu)
      return
    end
    local key = pocketFor(menu).key
    menu.items = makeRows(menu, key)
    if preserveId then
      for index, item in ipairs(menu.items) do
        if item.value == preserveId then
          menu.index = index
          break
        end
      end
    end
    clampList(menu)
    menu.modernBagInventorySignature = inventorySignature(menu)
    if menu.modernBagSwapId and not itemStore(menu)[menu.modernBagSwapId] then
      menu.modernBagSwapId = nil
    end
  end

  local function selectedId(menu)
    local item = menu.items and menu.items[menu.index]
    return item and item.value or nil
  end

  local function swapId(menu)
    if menu.modernBagSwapId then return menu.modernBagSwapId end
    local item = menu.swapIndex and menu.items and menu.items[menu.swapIndex]
    return item and item.value or nil
  end

  local function syncInventory(menu)
    local signature = inventorySignature(menu)
    if signature ~= menu.modernBagInventorySignature then
      rebuildPocket(menu, selectedId(menu))
    end
  end

  local function switchPocket(menu, delta)
    if menu.modernBagExternalController then
      local api = menu.gen1ModernUi
      if api and type(api.switchPocket) == "function" then
        api:switchPocket(delta or 0)
        syncExternalPocketIndex(menu)
        clampList(menu)
        menu.modernBagInventorySignature = inventorySignature(menu)
        menu.modernBagHeaderFlash = 0
      end
      return
    end
    local current = pocketFor(menu)
    menu.modernBagPocketState[current.key] = {
      id = selectedId(menu), index = menu.index, scroll = menu.scroll,
    }
    local pockets = pocketsFor(menu)
    menu.modernBagPocket = ((menu.modernBagPocket - 1 + delta) % #pockets) + 1
    menu.modernBagSwapId = nil
    local nextPocket = pocketFor(menu)
    local saved = menu.modernBagPocketState[nextPocket.key]
    menu.index = saved and saved.index or 1
    menu.scroll = saved and saved.scroll or 0
    rebuildPocket(menu, saved and saved.id)
    menu.modernBagHeaderFlash = 0
  end

  local function finishSwap(menu, targetId)
    local sourceId = menu.modernBagSwapId
    menu.modernBagSwapId = nil
    if not sourceId or not targetId then return end
    local order = Bag.order(menu.game.save)
    local sourceIndex, targetIndex
    for index, id in ipairs(order) do
      if id == sourceId then sourceIndex = index end
      if id == targetId then targetIndex = index end
    end
    if sourceIndex and targetIndex then
      order[sourceIndex], order[targetIndex] = order[targetIndex], order[sourceIndex]
      local ok = menu.game and menu.game.data
      if ok then require("src.core.Sound").play(menu.game.data, "Swap") end
    end
    rebuildPocket(menu, sourceId)
  end

  local function reorder(menu, item)
    if not item then return end
    if menu.modernBagSwapId then
      finishSwap(menu, item.value)
    else
      menu.modernBagSwapId = item.value
    end
  end

  local function pocketCounts(menu)
    local counts = { all = 0, items = 0, medicine = 0, balls = 0,
      machines = 0, key = 0, berries = 0 }
    local store = itemStore(menu)
    for _, id in ipairs(orderedIds(menu, store)) do
      if included(menu, id) then
        counts.all = counts.all + 1
        local category = categoryFor(menu.game, id)
        counts[category] = (counts[category] or 0) + 1
      end
    end
    return counts
  end

  local function drawClassicPokeBall16(x, y, trueColorZones, indexedRect)
    x, y = math.floor(x), math.floor(y)
    local function rgb(index, red, green, blue, rx, ry, rw, rh)
      if indexedRect then
        indexedRect(index, rx, ry, rw, rh)
        return
      end
      love.graphics.setColor(red / 255, green / 255, blue / 255, 1)
      love.graphics.rectangle("fill", x + rx, y + ry, rw, rh)
      if trueColorZones then
        trueColorZones[#trueColorZones + 1] = {
          colors = false, x = x + rx, y = y + ry, w = rw, h = rh,
        }
      end
    end
    rgb(4, 18, 18, 18, 6, 1, 4, 1)
    rgb(4, 18, 18, 18, 4, 2, 8, 1)
    rgb(4, 18, 18, 18, 3, 3, 10, 1)
    rgb(4, 18, 18, 18, 2, 4, 12, 1)
    rgb(4, 18, 18, 18, 1, 5, 14, 6)
    rgb(4, 18, 18, 18, 2, 11, 12, 1)
    rgb(4, 18, 18, 18, 3, 12, 10, 1)
    rgb(4, 18, 18, 18, 4, 13, 8, 1)
    rgb(4, 18, 18, 18, 6, 14, 4, 1)
    rgb(3, 232, 48, 48, 6, 2, 4, 1)
    rgb(3, 232, 48, 48, 5, 3, 6, 1)
    rgb(3, 232, 48, 48, 4, 4, 8, 1)
    rgb(3, 232, 48, 48, 3, 5, 10, 2)
    rgb(2, 255, 255, 255, 3, 9, 10, 2)
    rgb(2, 255, 255, 255, 4, 11, 8, 1)
    rgb(2, 255, 255, 255, 5, 12, 6, 1)
    rgb(2, 255, 255, 255, 6, 13, 4, 1)
    rgb(4, 18, 18, 18, 2, 7, 12, 2)
    rgb(4, 18, 18, 18, 6, 6, 4, 4)
    rgb(1, 255, 255, 255, 7, 7, 2, 2)
  end

  local CUSTOM_KEY_ICONS = {
    TOWN_MAP = true, BICYCLE = true, S_S_TICKET = true,
    COIN_CASE = true, ITEMFINDER = true, POKE_FLUTE = true,
    GOOD_ROD = true, SUPER_ROD = true,
  }

  local function drawCustomKeyItemIcon(id, x, y, trueColorZones)
    if not CUSTOM_KEY_ICONS[id] then return false end
    x, y = math.floor(x), math.floor(y)
    local function rect(color, rx, ry, rw, rh)
      love.graphics.setColor(color[1] / 255, color[2] / 255,
        color[3] / 255, 1)
      love.graphics.rectangle("fill", x + rx, y + ry, rw, rh)
      if trueColorZones then
        trueColorZones[#trueColorZones + 1] = {
          colors = false, x = x + rx, y = y + ry, w = rw, h = rh,
        }
      end
    end
    local black = { 18, 18, 18 }
    local white = { 250, 250, 250 }
    local silver = { 184, 198, 212 }
    local blue = { 42, 154, 232 }
    local cyan = { 94, 214, 236 }
    local gold = { 248, 184, 48 }
    local orange = { 224, 112, 24 }
    local green = { 72, 200, 72 }

    if id == "TOWN_MAP" then
      -- Three bright folded panels; no solid backing rectangle, so the map
      -- keeps its silhouette against the dark details card.
      rect(white, 2, 3, 5, 14)
      rect(cyan, 7, 3, 6, 14)
      rect(white, 13, 3, 5, 14)
      rect(green, 3, 5, 4, 4)
      rect(green, 8, 10, 5, 5)
      rect(green, 13, 6, 4, 4)
      rect(blue, 3, 12, 4, 3)
      rect(blue, 14, 12, 3, 3)
      rect(black, 6, 3, 1, 14)
      rect(black, 13, 3, 1, 14)
      rect(white, 2, 2, 5, 1); rect(cyan, 7, 2, 6, 1)
      rect(white, 13, 2, 5, 1)
      rect(white, 2, 17, 5, 1); rect(cyan, 7, 17, 6, 1)
      rect(white, 13, 17, 5, 1)
    elseif id == "BICYCLE" then
      rect(white, 1, 9, 2, 6); rect(white, 3, 7, 4, 2)
      rect(white, 3, 15, 4, 2); rect(white, 7, 9, 2, 6)
      rect(white, 11, 9, 2, 6); rect(white, 13, 7, 4, 2)
      rect(white, 13, 15, 4, 2); rect(white, 17, 9, 2, 6)
      rect(blue, 6, 8, 7, 2); rect(blue, 7, 10, 5, 3)
      rect(blue, 9, 5, 2, 6); rect(black, 7, 4, 5, 2)
      rect(black, 12, 3, 2, 5); rect(silver, 13, 2, 4, 2)
    elseif id == "S_S_TICKET" then
      rect(white, 1, 3, 18, 14); rect(gold, 2, 4, 16, 12)
      rect(white, 5, 5, 10, 10); rect(orange, 9, 5, 2, 10)
      rect(black, 2, 8, 3, 3); rect(black, 15, 8, 3, 3)
    elseif id == "COIN_CASE" then
      -- A single large coin, centered in the 20x20 icon cell.
      rect(black, 6, 1, 8, 1); rect(black, 3, 2, 14, 2)
      rect(black, 2, 4, 16, 3); rect(black, 1, 7, 18, 6)
      rect(black, 2, 13, 16, 3); rect(black, 3, 16, 14, 2)
      rect(black, 6, 18, 8, 1)
      rect(gold, 6, 2, 8, 1); rect(gold, 4, 4, 12, 2)
      rect(gold, 3, 6, 14, 8); rect(gold, 4, 14, 12, 2)
      rect(gold, 6, 16, 8, 1)
      rect(orange, 7, 5, 7, 10); rect(orange, 5, 7, 2, 6)
      rect(white, 6, 5, 3, 2); rect(white, 5, 7, 2, 4)
    elseif id == "ITEMFINDER" then
      rect(white, 3, 1, 8, 2); rect(white, 1, 3, 12, 2)
      rect(white, 1, 5, 2, 7); rect(white, 11, 5, 2, 7)
      rect(white, 3, 12, 8, 2); rect(cyan, 3, 3, 8, 9)
      rect(blue, 10, 11, 4, 4); rect(blue, 13, 14, 5, 4)
      rect(white, 16, 17, 3, 2)
    elseif id == "POKE_FLUTE" then
      rect(white, 1, 7, 18, 6); rect(gold, 2, 8, 16, 4)
      rect(orange, 4, 8, 2, 4); rect(orange, 8, 8, 2, 4)
      rect(orange, 12, 8, 2, 4); rect(black, 4, 9, 1, 2)
      rect(black, 8, 9, 1, 2); rect(black, 12, 9, 1, 2)
      rect(white, 17, 8, 1, 4)
    elseif id == "GOOD_ROD" or id == "SUPER_ROD" then
      local metal = id == "SUPER_ROD" and gold or silver
      -- Angled rod at left, white fishing line at right, visible hook below.
      rect(black, 1, 15, 5, 4); rect(orange, 2, 15, 4, 3)
      rect(black, 5, 12, 3, 5); rect(metal, 5, 12, 2, 4)
      rect(black, 7, 9, 3, 5); rect(metal, 7, 9, 2, 4)
      rect(black, 9, 6, 3, 5); rect(metal, 9, 6, 2, 4)
      rect(black, 11, 3, 3, 5); rect(metal, 11, 3, 2, 4)
      rect(black, 13, 1, 5, 3); rect(metal, 13, 1, 4, 2)
      rect(white, 17, 3, 2, 11); rect(white, 15, 13, 4, 2)
      rect(white, 14, 14, 2, 4); rect(white, 15, 17, 3, 2)
      rect(black, 16, 16, 3, 2)
    end
    return true
  end

  local KEY_ICON_FILL_MASK = {
    "..................",
    "...WWW............",
    "..WWWWW...........",
    ".WW..WWW..........",
    ".W....WW..........",
    ".W....WWWWWWWWWWW.",
    ".WW..WWW....W..W..",
    "..WWWWW.....W...W.",
    "...WWW............",
    "..................",
  }

  local function keyIconFillAt(column, row)
    local line = KEY_ICON_FILL_MASK[row + 1]
    return line and line:sub(column + 1, column + 1) == "W"
  end

  local function drawKeyIconMask(x, y, outlinePixel, fillPixel)
    for row = 0, #KEY_ICON_FILL_MASK - 1 do
      for column = 0, #KEY_ICON_FILL_MASK[row + 1] - 1 do
        if not keyIconFillAt(column, row) then
          local bordersFill = false
          for dy = -1, 1 do
            for dx = -1, 1 do
              bordersFill = bordersFill
                or keyIconFillAt(column + dx, row + dy)
            end
          end
          if bordersFill then outlinePixel(x + column, y + row) end
        end
      end
    end
    for row, line in ipairs(KEY_ICON_FILL_MASK) do
      for column = 1, #line do
        if line:sub(column, column) == "W" then
          fillPixel(x + column - 1, y + row - 1)
        end
      end
    end
  end

  local function drawBattleSymbol(x, y, size, lightRect, darkRect)
    local unit = math.max(1, math.floor(size / 8))
    lightRect(x + 3 * unit, y, 2 * unit, size)
    lightRect(x, y + 3 * unit, size, 2 * unit)
    darkRect(x + 2 * unit, y + 2 * unit, 4 * unit, 4 * unit)
  end

  local function drawPocketSymbol(key, x, y, size, trueColorZones)
    x, y, size = math.floor(x), math.floor(y), math.max(8, math.floor(size))
    local unit = math.max(1, math.floor(size / 8))
    local function markRect(rx, ry, rw, rh)
      if trueColorZones then
        trueColorZones[#trueColorZones + 1] = {
          colors = false, x = rx, y = ry, w = rw, h = rh,
        }
      end
    end
    local function fillRect(rx, ry, rw, rh)
      love.graphics.rectangle("fill", rx, ry, rw, rh)
      markRect(rx, ry, rw, rh)
    end
    local function lineRect(rx, ry, rw, rh)
      love.graphics.rectangle("line", rx, ry, rw, rh)
      markRect(rx, ry, rw + 1, 1)
      markRect(rx, ry + rh, rw + 1, 1)
      markRect(rx, ry + 1, 1, math.max(0, rh - 1))
      markRect(rx + rw, ry + 1, 1, math.max(0, rh - 1))
    end
    local function circle(mode, cx, cy, radius)
      love.graphics.circle(mode, cx, cy, radius)
      if not trueColorZones then return end
      local outer = math.floor(radius)
      local inner = mode == "line" and math.max(0, outer - 1) or 0
      for dy = -outer, outer do
        local span = math.floor(math.sqrt(math.max(0,
          radius * radius - dy * dy)))
        if mode == "fill" then
          markRect(math.floor(cx - span), math.floor(cy + dy),
            span * 2 + 1, 1)
        else
          local innerSpan = math.floor(math.sqrt(math.max(0,
            inner * inner - math.min(inner * inner, dy * dy))))
          local edge = math.max(1, span - innerSpan + 1)
          markRect(math.floor(cx - span), math.floor(cy + dy), edge, 1)
          markRect(math.floor(cx + span - edge + 1),
            math.floor(cy + dy), edge, 1)
        end
      end
    end
    if key == "all" then
      gray(DARK)
      lineRect(x + 2 * unit, y + unit, size - 4 * unit, 3 * unit)
      fillRect(x, y + 3 * unit, 2 * unit, size - 4 * unit)
      fillRect(x + size - 2 * unit, y + 3 * unit,
        2 * unit, size - 4 * unit)
      fillRect(x + 2 * unit, y + 2 * unit,
        size - 4 * unit, size - 2 * unit)
      gray(LIGHT)
      fillRect(x + 3 * unit, y + 3 * unit,
        size - 6 * unit, size - 4 * unit)
      gray(DARK)
      lineRect(x + 3 * unit, y + 5 * unit,
        size - 6 * unit, 2 * unit)
    elseif key == "items" then
      gray(LIGHT)
      if love.graphics.polygon then
        love.graphics.polygon("fill", x + size / 2, y,
          x + size, y + size / 2, x + size / 2, y + size,
          x, y + size / 2)
        if trueColorZones then
          for dy = 0, size do
            local half = math.floor(math.min(dy, size - dy))
            markRect(x + math.floor(size / 2) - half, y + dy,
              half * 2 + 1, 1)
          end
        end
      else
        fillRect(x + unit, y + unit, size - 2 * unit, size - 2 * unit)
      end
      gray(DARK)
      fillRect(x + size / 2 - unit / 2,
        y + 2 * unit, unit, size - 4 * unit)
    elseif key == "medicine" then
      gray(DARK)
      fillRect(x + 3 * unit, y, size - 6 * unit, 2 * unit)
      gray(LIGHT)
      fillRect(x + 2 * unit, y + 2 * unit,
        size - 4 * unit, size - 2 * unit)
      gray(BLACK)
      local crossX = x + math.floor((size - 3 * unit) / 2)
      local stemX = x + math.floor((size - unit) / 2)
      fillRect(crossX, y + 4 * unit, 3 * unit, unit)
      fillRect(stemX, y + 3 * unit, unit, 3 * unit)
    elseif key == "balls" then
      drawClassicPokeBall16(
        x + math.floor((size - 16) / 2),
        y + math.floor((size - 16) / 2), trueColorZones)
    elseif key == "battle" then
      drawBattleSymbol(x, y, size, function(rx, ry, rw, rh)
        gray(LIGHT)
        fillRect(rx, ry, rw, rh)
      end, function(rx, ry, rw, rh)
        gray(DARK)
        fillRect(rx, ry, rw, rh)
      end)
    elseif key == "machines" then
      gray(LIGHT)
      circle("fill", x + size / 2, y + size / 2, size / 2)
      gray(DARK)
      circle("fill", x + size / 2, y + size / 2, 3 * unit)
      gray(BLACK)
      circle("fill", x + size / 2, y + size / 2, unit)
    elseif key == "key" then
      local keyX = x + math.floor((size - 18) / 2)
      local keyY = y + math.floor((size - 10) / 2)
      drawKeyIconMask(keyX, keyY, function(px, py)
        gray(BLACK)
        fillRect(px, py, 1, 1)
      end, function(px, py)
        love.graphics.setColor(94 / 255, 214 / 255, 236 / 255, 1)
        fillRect(px, py, 1, 1)
      end)
    elseif key == "berries" then
      gray(LIGHT)
      circle("fill", x + size / 2, y + size / 2 + unit, 3 * unit)
      gray(DARK)
      fillRect(x + 4 * unit, y, unit, 3 * unit)
      fillRect(x + 5 * unit, y + unit, 2 * unit, unit)
      gray(BLACK)
      fillRect(x + 3 * unit, y + 4 * unit, unit, unit)
    end
  end

  -- Fixed 16x16 header glyphs emit canonical four-shade source indices. The
  -- centralized menu-palette pass owns their final colors.
  local function drawHeaderPocketIcon(menu, pocket, x, y)
    x, y = math.floor(x), math.floor(y)
    local function shade(index)
      gray(({ WHITE, LIGHT, DARK, BLACK })[index] or BLACK)
    end
    local function rect(index, rx, ry, rw, rh)
      shade(index)
      love.graphics.rectangle("fill", x + rx, y + ry, rw, rh)
      local zones = menu.modernBagHeaderIconZones
      if zones then
        zones[#zones + 1] = {
          x = x + rx, y = y + ry, w = rw, h = rh,
        }
      end
    end
    local key = pocket.key
    if key == "all" then
      rect(4, 3, 1, 10, 2)
      rect(3, 1, 4, 14, 10)
      rect(2, 3, 3, 10, 10)
      rect(1, 4, 5, 8, 3)
      rect(3, 4, 10, 8, 2)
    elseif key == "items" then
      rect(4, 7, 1, 2, 1)
      rect(4, 6, 2, 4, 1)
      rect(4, 5, 3, 6, 1)
      rect(4, 4, 4, 8, 1)
      rect(4, 3, 5, 10, 1)
      rect(4, 2, 6, 12, 1)
      rect(4, 1, 7, 14, 1)
      rect(4, 2, 8, 12, 1)
      rect(4, 3, 9, 10, 1)
      rect(4, 4, 10, 8, 1)
      rect(4, 5, 11, 6, 1)
      rect(4, 6, 12, 4, 1)
      rect(4, 7, 13, 2, 1)
      rect(1, 7, 4, 2, 1)
      rect(1, 6, 5, 4, 1)
      rect(2, 5, 6, 6, 3)
      rect(3, 6, 9, 4, 1)
      rect(3, 7, 10, 2, 1)
    elseif key == "medicine" then
      rect(3, 5, 1, 6, 2)
      rect(2, 4, 3, 8, 12)
      rect(2, 5, 5, 6, 8)
      rect(4, 7, 6, 2, 6)
      rect(4, 5, 8, 6, 2)
    elseif key == "balls" then
      -- The header Poké Ball participates in the active menu palette.
      drawClassicPokeBall16(x, y, nil, function(index, rx, ry, rw, rh)
        rect(index, rx, ry, rw, rh)
      end)
    elseif key == "battle" then
      drawBattleSymbol(x, y, 16, function(rx, ry, rw, rh)
        rect(2, rx - x, ry - y, rw, rh)
      end, function(rx, ry, rw, rh)
        rect(3, rx - x, ry - y, rw, rh)
      end)
      rect(1, 7, 1, 2, 3)
      rect(4, 7, 12, 2, 3)
    elseif key == "machines" then
      -- Concentric four-shade bullseye for the TM/HM pocket.
      rect(4, 6, 1, 4, 1)
      rect(4, 4, 2, 8, 1)
      rect(4, 3, 3, 10, 2)
      rect(4, 2, 5, 12, 6)
      rect(4, 3, 11, 10, 2)
      rect(4, 4, 13, 8, 1)
      rect(4, 6, 14, 4, 1)
      rect(2, 6, 2, 4, 1)
      rect(2, 4, 3, 8, 2)
      rect(2, 3, 5, 10, 6)
      rect(2, 4, 11, 8, 2)
      rect(2, 6, 13, 4, 1)
      rect(3, 6, 5, 4, 1)
      rect(3, 5, 6, 6, 4)
      rect(3, 6, 10, 4, 1)
      rect(2, 7, 7, 2, 2)
    else -- MISC / key items
      drawKeyIconMask(x - 1, y + 3, function(px, py)
        rect(4, px - x, py - y, 1, 1)
      end, function(px, py)
        rect(3, px - x, py - y, 1, 1)
      end)
    end
  end

  local function drawBackdrop(layout)
    gray(WHITE)
    love.graphics.rectangle("fill", 0, 0, layout.width, layout.height)
    gray(LIGHT)
    for x = -layout.height, layout.width, 16 do
      love.graphics.line(x, layout.headerH,
        x + layout.height, layout.footerY)
      love.graphics.line(x + layout.height, layout.headerH,
        x, layout.footerY)
    end
  end

  local function drawHeader(menu, layout)
    local pocket = pocketFor(menu)
    local config = listConfig(menu)
    gray(DARK)
    love.graphics.rectangle("fill", 0, 0, layout.width, layout.headerH)
    gray(LIGHT)
    love.graphics.rectangle("fill", 0, layout.headerH - 2,
      layout.width, 2)
    drawText(Strings(config and config.header or "BAG"), 5,
      layout.stacked and 2 or 4, 32, WHITE)

    local capacity
    if config and type(config.capacity) == "function" then
      capacity = tostring(config.capacity(menu) or "")
    else
      capacity = ("%d/%d"):format(Bag.slots(menu.game.save),
        Bag.capacity(menu.game.data))
    end
    drawTextRight(capacity, layout.width - 5, layout.stacked and 2 or 4,
      48, WHITE)

    local label
    if config then
      label = (layout.wide or layout.stacked)
        and (config.label or config.short) or config.short
    else
      label = (layout.wide or layout.stacked) and pocket.label or pocket.short
    end
    -- The right side already reports the total slot count. Repeating the
    -- active pocket count after the label made ALL ITEMS read like
    -- "ALL ITEMS 4646/255" once the Bag held 46 unique items.
    local center = Strings(label)
    local centerWidth = layout.stacked and (layout.width - 26)
      or math.max(24, layout.width - 112)
    center = fitText(center, centerWidth)
    local selectorW = math.min(layout.width - 72,
      math.max(40, Font.width(center) + 16))
    local selectorX = math.floor((layout.width - selectorW) / 2)
    local selectorY = layout.stacked and 13 or 4
    love.graphics.push("all")
    local ink = shaderForInk()
    if ink then love.graphics.setShader(ink) end
    gray(WHITE)
    love.graphics.translate(selectorX + 8, selectorY)
    love.graphics.scale(-1, 1)
    Font.drawCode(Theme.cursor, 0, 0)
    love.graphics.pop()
    drawCode(Theme.cursor, selectorX + selectorW - 8, selectorY, WHITE)
    drawText(center,
      selectorX + math.floor((selectorW - Font.width(center)) / 2),
      selectorY, selectorW - 16, WHITE)
  end

  local function drawTabs(menu, layout, counts)
    gray(LIGHT)
    love.graphics.rectangle("fill", 0, layout.tabsY,
      layout.width, layout.tabsH)
    local pockets = pocketsFor(menu)
    local slotW = math.floor(layout.width / #pockets)
    local tileW = math.min(28, slotW - 4)
    local tileH = 18
    local flashPhase = math.floor((menu.modernBagHeaderFlash or 0) / 60)
    local selectedDark = flashPhase == 0 or flashPhase == 2
      or flashPhase >= 4

    local function recordBorder(x, y, width, height)
      local zones = menu.modernBagHeaderBorderZones
      if not zones then return end
      local function add(rx, ry, rw, rh)
        zones[#zones + 1] = { x = rx, y = ry, w = rw, h = rh }
      end
      add(x + 2, y, width - 4, 1)
      add(x + 1, y + 1, 1, 1)
      add(x + width - 2, y + 1, 1, 1)
      add(x, y + 2, 1, height - 4)
      add(x + width - 1, y + 2, 1, height - 4)
      add(x + 1, y + height - 2, 1, 1)
      add(x + width - 2, y + height - 2, 1, 1)
      add(x + 2, y + height - 1, width - 4, 1)
    end

    for index, pocket in ipairs(pockets) do
      local slotX = (index - 1) * slotW
      local x = slotX + math.floor((slotW - tileW) / 2)
      local y = layout.tabsY - 1
      local active = index == menu.modernBagPocket
      gray(active and selectedDark and BLACK or DARK)
      pixelRoundFill(x, y, tileW, tileH)
      recordBorder(x, y, tileW, tileH)
      gray(WHITE)
      pixelRoundFill(x + 1, y + 1, tileW - 2, tileH - 2)
      drawHeaderPocketIcon(menu, pocket,
        x + math.floor((tileW - 16) / 2), y + 1)
    end
  end

  local function drawWallpaperDivider(layout)
    gray(DARK)
    love.graphics.rectangle("fill", 0, layout.contentY, layout.width, 1)
  end

  local function drawList(menu, layout)
    gray(DARK)
    pixelRoundFill(layout.listX, layout.listY,
      layout.listW, layout.listH)
    gray(LIGHT)
    pixelRoundFill(layout.listX + 2, layout.listY + 2,
      layout.listW - 4, layout.listH - 4)

    if #menu.items == 0 then
      local config = listConfig(menu)
      local empty = config and config.empty
      local line1 = Strings(empty and empty[1] or "THIS POCKET")
      local line2 = Strings(empty and empty[2] or "IS EMPTY")
      drawText(line1, layout.listX + (layout.listW - Font.width(line1)) / 2,
        layout.listY + 31, layout.listW - 12, DARK)
      drawText(line2, layout.listX + (layout.listW - Font.width(line2)) / 2,
        layout.listY + 43, layout.listW - 12, DARK)
      return
    end

    local visibleRows = math.min(layout.rows,
      math.max(0, #menu.items - menu.scroll))
    local stackH = (layout.rows - 1) * ROW_H + 12
    local stackY = layout.listY + math.floor((layout.listH - stackH) / 2)

    for row = 1, visibleRows do
      local index = menu.scroll + row
      local item = menu.items[index]
      if not item then break end
      local y = stackY + 1 + (row - 1) * ROW_H
      local selected = index == menu.index
      if selected then
        gray(BLACK)
        pixelRoundFill(layout.listX + 4, y - 1,
          layout.listW - 8, 12)
        gray(DARK)
        pixelRoundFill(layout.listX + 5, y,
          layout.listW - 10, 10)
      else
        gray(WHITE)
        pixelRoundFill(layout.listX + 4, y - 1,
          layout.listW - 8, 12)
      end

      local shade = selected and WHITE or BLACK
      local quantity = item.right or ""
      local qWidth = Font.width(quantity)
      drawText(item.label, layout.listX + 17, y + 1,
        layout.listW - qWidth - 30, shade)
      drawTextRight(quantity, layout.listX + layout.listW - 8, y + 1,
        qWidth + 8, shade)
      if selected then
        drawCode(Theme.cursor, layout.listX + 7, y + 1, shade)
      elseif item.value == swapId(menu) then
        drawCode(Theme.cursorHollow, layout.listX + 7, y + 1, BLACK)
      end
    end

    if menu.scroll > 0 then
      gray(DARK)
      local centerX = layout.listX + math.floor(layout.listW / 2)
      local baseY = stackY - 1
      if love.graphics.polygon then
        love.graphics.polygon("fill", centerX - 2, baseY,
          centerX + 2, baseY, centerX, baseY - 3)
      else
        love.graphics.rectangle("fill", centerX - 1, baseY - 2, 3, 2)
      end
    end
    if menu.scroll + visibleRows < #menu.items then
      gray(DARK)
      local centerX = layout.listX + math.floor(layout.listW / 2)
      local arrowY = stackY + stackH + 1
      if love.graphics.polygon then
        love.graphics.polygon("fill", centerX - 2, arrowY,
          centerX + 2, arrowY, centerX, arrowY + 3)
      else
        love.graphics.rectangle("fill", centerX - 1, arrowY + 1, 3, 2)
      end
    end
  end

  local function withoutSingleSentencePeriod(description)
    if type(description) ~= "string" or description:sub(-1) ~= "." then
      return description
    end
    if description:sub(1, -2):find("[.!?]%s") then return description end
    return description:sub(1, -2)
  end

  local function itemDescription(menu, id)
    if not id then return Strings("Return to the previous screen") end
    local def = menu.game.data.items[id] or {}
    local description
    if type(def.description) == "string" and def.description ~= "" then
      description = Strings(def.description)
    elseif DESCRIPTIONS[id] then
      description = Strings(DESCRIPTIONS[id])
    elseif def.machine then
      local move = menu.game.data.moves and menu.game.data.moves[def.machine.move]
      local moveName = move and move.name or def.machine.move
      description = Strings("Teaches %s to a compatible POKéMON.", moveName)
    else
      local category = categoryFor(menu.game, id)
      if category == "balls" then
        description = Strings("A device for catching wild POKéMON.")
      elseif category == "medicine" then
        description = Strings("A medicine used to help a POKéMON.")
      elseif category == "battle" then
        description = Strings("An item intended for use in battle.")
      elseif category == "key" then
        description = Strings("An important item for your adventure.")
      elseif category == "berries" then
        description = Strings("A Berry that a POKéMON can use or hold.")
      else
        description = Strings("A useful item for your journey.")
      end
    end
    return withoutSingleSentencePeriod(description)
  end

  local function drawDetails(menu, layout)
    if not layout.showDetails then return end
    local pocket = pocketFor(menu)

    if layout.stacked then
      gray(WHITE)
      pixelRoundFill(layout.detailX, layout.detailY,
        layout.detailW, layout.detailH)
      gray(LIGHT)
      pixelRoundFill(layout.detailX + 2, layout.detailY + 2,
        layout.detailW - 4, layout.detailH - 4)

      local item = menu.items[menu.index]
      local config = listConfig(menu)
      local caption = config and config.direction
      if caption then
        drawText(caption:upper(), layout.detailX + 6, layout.detailY + 5,
          math.floor(layout.detailW * 0.58), DARK)
      end
      local status = config and type(config.detailStatus) == "function"
        and config.detailStatus(menu)
        or ("¥%d"):format(menu.game.save.money or 0)
      drawTextRight(status, layout.detailX + layout.detailW - 6,
        layout.detailY + 5, math.floor(layout.detailW * 0.42), DARK)

      local category = item and categoryFor(menu.game, item.value) or pocket.key
      local iconSize = math.min(28, math.max(20, layout.detailH - 56))
      local iconX, iconY = layout.detailX + 8, layout.detailY + 20
      if not (item and drawCustomKeyItemIcon(item.value,
          iconX + math.floor((iconSize - 20) / 2),
          iconY + math.floor((iconSize - 20) / 2),
          menu.modernBagIconZones)) then
        drawPocketSymbol(category, iconX, iconY, iconSize,
          menu.modernBagIconZones)
      end
      local textX = layout.detailX + iconSize + 14
      local textW = layout.detailX + layout.detailW - 6 - textX
      local name = item and item.label
        or (config and config.emptyName) or pocket.label
      local nameLines = wrappedLines(name, textW, 2)
      for index, line in ipairs(nameLines) do
        drawText(line, textX, layout.detailY + 24 + (index - 1) * 9,
          textW, BLACK)
      end
      local description = item and itemDescription(menu, item.value)
        or Strings(config and config.blurb or pocket.blurb)
      local descriptionY = layout.detailY + 20 + iconSize + 4
      local descriptionW = layout.detailW - 12
      local maxLines = math.max(2, math.floor(
        (layout.detailY + layout.detailH - 4 - descriptionY) / 9))
      for index, line in ipairs(wrappedLines(
          description, descriptionW, maxLines)) do
        drawText(line, layout.detailX + 6,
          descriptionY + (index - 1) * 9, descriptionW, DARK)
      end
      return
    end

    gray(DARK)
    pixelRoundFill(layout.detailX, layout.detailY,
      layout.detailW, layout.detailH)
    gray(WHITE)
    pixelRoundFill(layout.detailX + 2, layout.detailY + 2,
      layout.detailW - 4, layout.detailH - 4)

    local item = menu.items[menu.index]
    local config = listConfig(menu)
    local caption = config and config.direction
    if caption then
      drawText(caption:upper(), layout.detailX + 6, layout.detailY + 5,
        layout.detailW - 12, BLACK)
    end

    if item then
      local category = categoryFor(menu.game, item.value)
      local iconSize = 24
      local customIcon = CUSTOM_KEY_ICONS[item.value]
      local iconX, iconY
      if customIcon then
        -- Custom art owns a 20x20 painted box centered directly in the
        -- details column's upper icon region. This uses the art bounds—not a
        -- larger generic 24px wrapper—and leaves a full 15px before the name.
        iconX = layout.detailX + math.floor((layout.detailW - 20) / 2)
        iconY = layout.detailY + 10
        drawCustomKeyItemIcon(item.value, iconX, iconY,
          menu.modernBagIconZones)
      else
        iconX = layout.detailX + math.floor((layout.detailW - iconSize) / 2)
        iconY = layout.detailY + 17
        drawPocketSymbol(category, iconX, iconY, iconSize,
          menu.modernBagIconZones)
      end
      local nameLines = wrappedLines(item.label, layout.detailW - 12, 2)
      for index, line in ipairs(nameLines) do
        drawText(line,
          layout.detailX + (layout.detailW - Font.width(line)) / 2,
          layout.detailY + 45 + (index - 1) * 9,
          layout.detailW - 12, BLACK)
      end
      local descriptionY = layout.detailY + 58
        + math.max(0, #nameLines - 1) * 9
      local descriptionLines
      if config then
        descriptionLines = math.max(1, math.floor(
          (layout.detailY + layout.detailH - 2 - descriptionY - 8) / 9) + 1)
      else
        descriptionLines = math.max(1, math.floor(
          (layout.detailY + layout.detailH - 14 - descriptionY) / 9))
      end
      local lines = wrappedLines(itemDescription(menu, item.value),
        layout.detailW - 12, descriptionLines)
      for index, line in ipairs(lines) do
        drawText(line, layout.detailX + 6,
          descriptionY + (index - 1) * 9,
          layout.detailW - 12, BLACK)
      end
    else
      drawPocketSymbol(pocket.key,
        layout.detailX + math.floor((layout.detailW - 28) / 2),
        layout.detailY + 20, 28, menu.modernBagIconZones)
      local lines = wrappedLines(
        Strings(config and config.blurb or pocket.blurb),
        layout.detailW - 12, 3)
      for index, line in ipairs(lines) do
        drawText(line, layout.detailX + 6,
          layout.detailY + 58 + (index - 1) * 9,
          layout.detailW - 12, BLACK)
      end
    end

    if not config then
      local status = ("¥%d"):format(menu.game.save.money or 0)
      drawTextRight(status, layout.detailX + layout.detailW - 6,
        layout.detailY + layout.detailH - 11, layout.detailW - 12, BLACK)
    end
  end

  local function drawFooter(menu, layout)
    gray(DARK)
    love.graphics.rectangle("fill", 0, layout.footerY,
      layout.width,
      math.max(layout.footerH,
        (layout.canvasHeight or layout.height) - layout.footerY + 1))
    local config = listConfig(menu)
    if config or menu.modernBagPrompt then
      local lines
      local status = config and menu.footer or menu.modernBagPrompt
      if status then
        lines = wrappedLines(Strings(status):gsub("\n", " "),
          layout.width - 8, 2)
      elseif config and layout.wide then
        lines = { Strings("[L/R] POCKET   [A] SELECT   [B] BACK") }
      else
        lines = { Strings("L/R POCKET"), Strings("A SELECT  B BACK") }
      end
      if #lines == 0 then lines = { "" } end
      local step = 8
      local y = layout.footerY
        + math.max(0, math.floor((layout.footerH - #lines * step) / 2))
      for index, line in ipairs(lines) do
        line = fitText(line, layout.width - 8)
        drawText(line, (layout.width - Font.width(line)) / 2,
          y + (index - 1) * step, layout.width - 8, WHITE)
      end
      return
    end
    if layout.stacked then
      local line1, line2
      if swapId(menu) then
        line1 = Strings("CHOOSE NEW POSITION")
        line2 = Strings("A PLACE  B BACK")
      else
        line1 = Strings("[L/R] CHANGE POCKET")
        line2 = Strings("[A] USE   [B] BACK")
      end
      line1 = fitText(line1, layout.width - 8)
      line2 = fitText(line2, layout.width - 8)
      drawText(line1, (layout.width - Font.width(line1)) / 2,
        layout.footerY + 1, layout.width - 8, WHITE)
      drawText(line2, (layout.width - Font.width(line2)) / 2,
        layout.footerY + 11, layout.width - 8, WHITE)
      return
    end

    if layout.wide and not swapId(menu) then
      local labels = {
        Strings("[B] BACK"), Strings("POCKET"), Strings("[A] SELECT"),
      }
      local gap = 16
      local arrowW = 12
      local widths = { Font.width(labels[1]), arrowW + Font.width(labels[2]),
        Font.width(labels[3]) }
      local stride = widths[1] + widths[2] + widths[3] + gap * 3
      local offset = math.floor((menu.marquee or 0) / 8) % stride
      local sx, sy, sw, sh = love.graphics.getScissor()
      love.graphics.setScissor(0, layout.footerY, layout.width, layout.footerH)
      local function arrows(px)
        gray(WHITE)
        love.graphics.polygon("fill", px, layout.footerY + 5,
          px + 3, layout.footerY + 2, px + 3, layout.footerY + 8)
        love.graphics.polygon("fill", px + 9, layout.footerY + 5,
          px + 6, layout.footerY + 2, px + 6, layout.footerY + 8)
      end
      local startX = -offset
      while startX < layout.width do
        local x = startX
        drawText(labels[1], x, layout.footerY + 1, widths[1], WHITE)
        x = x + widths[1] + gap
        arrows(x)
        drawText(labels[2], x + arrowW, layout.footerY + 1,
          Font.width(labels[2]), WHITE)
        x = x + widths[2] + gap
        drawText(labels[3], x, layout.footerY + 1, widths[3], WHITE)
        startX = startX + stride
      end
      if sx then
        love.graphics.setScissor(sx, sy, sw, sh)
      else
        love.graphics.setScissor()
      end
      return
    end

    local message
    if swapId(menu) then
      message = Strings("CHOOSE A NEW POSITION")
    else
      message = Strings("[L/R] POCKET   [B] BACK")
    end
    local footerX = 4
    local footerW = layout.width - 8
    local textW = Font.width(message)
    local marqueeEnabled = mod and mod.options
      and mod.options:get("marquee_text") ~= false
    if textW <= footerW or not marqueeEnabled then
      message = fitText(message, footerW)
      drawText(message, (layout.width - Font.width(message)) / 2,
        layout.footerY + 1, footerW, WHITE)
    else
      local gap = 24
      local stride = textW + gap
      local offset = math.floor((menu.marquee or 0) / 8) % stride
      local sx, sy, sw, sh = love.graphics.getScissor()
      love.graphics.setScissor(footerX, layout.footerY,
        footerW, layout.footerH)
      local x = footerX - offset
      while x < footerX + footerW do
        drawText(message, x, layout.footerY + 1, textW, WHITE)
        x = x + stride
      end
      if sx then
        love.graphics.setScissor(sx, sy, sw, sh)
      else
        love.graphics.setScissor()
      end
    end
  end

  -- A second skin inspired by the late-era Pocket Bag: a black title strip,
  -- woven blue pocket rail, red active-pocket frame, clean white item sheet
  -- and a full-width description card. It keeps the same controller and
  -- responsive layout contract as the modern skin.
  local function drawClassicBackdrop(layout)
    gray(BLACK)
    love.graphics.rectangle("fill", 0, 0,
      layout.width, layout.canvasHeight or layout.height)
    gray(WHITE)
    love.graphics.rectangle("fill", 0, 0, layout.width, layout.height)
    gray(BLACK)
    love.graphics.rectangle("fill", 0, 0, layout.width, layout.headerH)

    gray(LIGHT)
    love.graphics.rectangle("fill", layout.railX, layout.railY,
      layout.railW, layout.railH)
    for y = layout.railY, layout.railY + layout.railH - 1, 4 do
      local phase = math.floor((y - layout.railY) / 4) % 2
      for x = layout.railX + phase * 2,
          layout.railX + layout.railW - 1, 4 do
        gray(DARK)
        love.graphics.rectangle("fill", x, y, 2, 2)
        gray(WHITE)
        love.graphics.rectangle("fill", x + 2, y + 2, 2, 2)
      end
    end
  end

  local function drawClassicHeader(menu, layout)
    local pocket = pocketFor(menu)
    local config = listConfig(menu)
    local left = "POCKET"
    local leftW = layout.topRail and 48 or layout.railW
    drawText(fitText(Strings(left), leftW), 0,
      math.max(2, math.floor((layout.headerH - 8) / 2)),
      leftW, WHITE)

    local titleSource
    if config then
      titleSource = layout.topRail and (config.short or config.label)
        or (config.label or config.short)
    else
      titleSource = layout.topRail and pocket.short or pocket.label
    end
    local title = Strings(titleSource)
    local capacity
    if config and type(config.capacity) == "function" then
      capacity = tostring(config.capacity(menu) or "")
    else
      capacity = ("%d/%d"):format(Bag.slots(menu.game.save),
        Bag.capacity(menu.game.data))
    end
    local capacityW = math.min(48, Font.width(capacity) + 4)
    local titleX = layout.topRail and leftW or layout.listX
    local titleW = layout.topRail
      and math.max(24, layout.width - titleX - capacityW - 4)
      or math.max(24, layout.listW - capacityW - 8)
    title = fitText(title, titleW)
    drawText(title,
      titleX + math.max(2, math.floor((titleW - Font.width(title)) / 2)),
      math.max(2, math.floor((layout.headerH - 8) / 2)), titleW, LIGHT)
    drawTextRight(capacity, layout.width - 3,
      math.max(2, math.floor((layout.headerH - 8) / 2)), capacityW, WHITE)
  end

  local function classicRailBoxes(layout)
    if layout.topRail then
      return {
        bagX = layout.railX + 4,
        bagY = layout.railY + 6,
        bagW = 48,
        bagH = 36,
        pocketX = layout.railX + 56,
        pocketY = layout.railY + 10,
        pocketW = layout.railW - 60,
        pocketH = 28,
      }
    end
    local margin = layout.wide and 5 or 3
    local bagH = layout.wide and 36 or 30
    local bagY = layout.railY + 4
    local pocketH = layout.wide and 28 or 25
    local pocketY = math.min(layout.railY + layout.railH - pocketH - 5,
      bagY + bagH + 8)
    return {
      bagX = layout.railX + margin,
      bagY = bagY,
      bagW = layout.railW - margin * 2,
      bagH = bagH,
      pocketX = layout.railX + margin,
      pocketY = pocketY,
      pocketW = layout.railW - margin * 2,
      pocketH = pocketH,
    }
  end

  local function classicBagRegionAt(x, y)
    -- The reference screenshot is in Items and visibly selects the left-side
    -- compartment. Continue from there through the main and two front pockets
    -- before ending at the right-side Key Items compartment.
    if x >= 4 and x <= 5 and y >= 8 and y <= 18 then return "items" end
    if x >= 12 and x <= 21 and y >= 2 and y <= 10 then return "medicine" end
    if x >= 12 and x <= 21 and y >= 12 and y <= 13 then return "balls" end
    if x >= 12 and x <= 21 and y >= 15 and y <= 17 then return "machines" end
    if x >= 27 and x <= 28 and y >= 9 and y <= 18 then return "key" end
  end

  local function loadClassicBagSprites()
    if classicBagSprites ~= nil then return classicBagSprites or nil end
    if not (love.image and love.image.newImageData
        and love.graphics and love.graphics.newImage) then
      classicBagSprites = false
      return nil
    end

    local sprites = {}
    local spritePockets = {}
    for _, pocket in ipairs(POCKETS) do spritePockets[#spritePockets + 1] = pocket end
    for _, pocket in ipairs(KANTO_POCKETS) do
      spritePockets[#spritePockets + 1] = pocket
    end
    for _, pocket in ipairs(spritePockets) do
      local okData, data = pcall(Assets.imageData, CLASSIC_BAG_ASSET)
      if not okData or not data or not data.mapPixel then
        classicBagSprites = false
        return nil
      end
      data:mapPixel(function(x, y, r, g, b, a)
        local region = classicBagRegionAt(x, y)
        local active = region
          and (CLASSIC_BAG_REGIONS[pocket.key] or pocket.key) == region

        -- The source screenshot shows its left pocket selected. Neutralize
        -- that fill first, then apply the same black fill as every other
        -- selected compartment so all five states behave consistently.
        if region == "items" and r < 0.17 then
          local shade = active and BLACK or WHITE
          return shade, shade, shade, a
        end
        if active and r > 0.83 and g > 0.83 and b > 0.83 then
          return BLACK, BLACK, BLACK, a
        end
        return r, g, b, a
      end)
      local okImage, image = pcall(love.graphics.newImage, data)
      if not okImage or not image then
        classicBagSprites = false
        return nil
      end
      if image.setFilter then image:setFilter("nearest", "nearest") end
      sprites[pocket.key] = image
    end
    classicBagSprites = sprites
    return sprites
  end

  local function drawClassicPocketBag(key, x, y, width, height)
    local sprites = loadClassicBagSprites()
    local sprite = sprites and (sprites[key] or sprites.all)
    if sprite and love.graphics.draw then
      local sw, sh = sprite:getDimensions()
      gray(WHITE)
      love.graphics.draw(sprite,
        math.floor(x + (width - sw) / 2),
        math.floor(y + (height - sh) / 2))
      return true
    end

    -- Headless tests and damaged installs still receive a safe fallback.
    local size = math.min(26, height - 8, width - 8)
    drawPocketSymbol("all", x + math.floor((width - size) / 2),
      y + math.floor((height - size) / 2), size)
    return false
  end

  local function drawClassicRail(menu, layout)
    local pocket = pocketFor(menu)
    local boxes = classicRailBoxes(layout)

    gray(BLACK)
    love.graphics.rectangle("fill", boxes.bagX - 1, boxes.bagY - 1,
      boxes.bagW + 2, boxes.bagH + 2)
    gray(WHITE)
    love.graphics.rectangle("fill", boxes.bagX, boxes.bagY,
      boxes.bagW, boxes.bagH)
    drawClassicPocketBag(pocket.key, boxes.bagX, boxes.bagY,
      boxes.bagW, boxes.bagH)
    menu.modernBagClassicPocketArt = pocket.key
    menu.modernBagClassicPocketRegion = CLASSIC_BAG_REGIONS[pocket.key]

    gray(DARK)
    love.graphics.rectangle("fill", boxes.pocketX - 1, boxes.pocketY - 1,
      boxes.pocketW + 2, boxes.pocketH + 2)
    gray(BLACK)
    love.graphics.rectangle("fill", boxes.pocketX + 2, boxes.pocketY + 2,
      boxes.pocketW - 4, boxes.pocketH - 4)
    local label = CLASSIC_POCKET_LABELS[pocket.key] or pocket.short
    menu.modernBagClassicPocketLabel = classicRailLabel(Strings(label),
      boxes.pocketX + 4, boxes.pocketY + 2,
      boxes.pocketW - 8, boxes.pocketH - 4)
  end

  local function drawClassicList(menu, layout)
    gray(BLACK)
    if layout.topRail then
      love.graphics.rectangle("fill", layout.listX, layout.listY - 1,
        layout.listW, 1)
    else
      love.graphics.rectangle("fill", layout.listX - 1, layout.listY,
        1, layout.listH)
    end
    gray(WHITE)
    love.graphics.rectangle("fill", layout.listX, layout.listY,
      layout.listW, layout.listH)

    if #menu.items == 0 then
      local config = listConfig(menu)
      local empty = config and config.empty
      local line1 = Strings(empty and empty[1] or "THIS POCKET")
      local line2 = Strings(empty and empty[2] or "IS EMPTY")
      drawText(line1,
        layout.listX + (layout.listW - Font.width(line1)) / 2,
        layout.listY + 22, layout.listW - 8, BLACK)
      drawText(line2,
        layout.listX + (layout.listW - Font.width(line2)) / 2,
        layout.listY + 34, layout.listW - 8, BLACK)
      return
    end

    for row = 1, layout.rows do
      local index = menu.scroll + row
      local item = menu.items[index]
      if not item then break end
      local y = layout.listY + 6 + (row - 1) * ROW_H
      local selected = index == menu.index
      local quantity = item.right or ""
      local qWidth = Font.width(quantity)
      if selected then
        drawCode(Theme.cursor, layout.listX + 8, y, DARK)
      elseif item.value == swapId(menu) then
        drawCode(Theme.cursorHollow, layout.listX + 8, y, BLACK)
      end
      drawText(item.label, layout.listX + 20, y,
        layout.listW - qWidth - 28, BLACK)
      drawTextRight(quantity, layout.width - 4, y, qWidth + 4, BLACK)
    end

    if menu.scroll + layout.rows < #menu.items then
      drawCode(Theme.moreArrow, layout.width - 10,
        layout.listY + layout.listH - 10, BLACK)
    end
  end

  local function drawClassicDetails(menu, layout)
    gray(BLACK)
    love.graphics.rectangle("fill", layout.detailX + 2,
      layout.detailY + 2, layout.detailW - 4, layout.detailH - 2)
    gray(WHITE)
    love.graphics.rectangle("fill", layout.detailX + 4,
      layout.detailY + 4, layout.detailW - 8, layout.detailH - 6)
    gray(BLACK)
    local x, y = layout.detailX + 6, layout.detailY + 6
    local w, h = layout.detailW - 12, layout.detailH - 10
    love.graphics.rectangle("fill", x, y, w, 1)
    love.graphics.rectangle("fill", x, y + h - 1, w, 1)
    love.graphics.rectangle("fill", x, y, 1, h)
    love.graphics.rectangle("fill", x + w - 1, y, 1, h)

    local config = listConfig(menu)
    local status = config and menu.footer or menu.modernBagPrompt
    local text
    if status then
      text = Strings(status):gsub("\n", " ")
    elseif swapId(menu) then
      local swapping = swapId(menu)
      local def = menu.game.data.items[swapping] or {}
      text = Strings("Choose a new position for %s.",
        def.name or swapping)
    else
      local item = menu.items[menu.index]
      text = item and itemDescription(menu, item.value)
        or Strings(config and config.blurb or pocketFor(menu).blurb)
    end
    local textX = layout.detailX + 10
    local textY = layout.detailY + 10
    local textW = layout.detailW - 20
    local maxLines = math.max(2, math.floor((layout.detailH - 18) / 9))
    if config and config.direction then
      drawText(fitText(Strings(config.direction), textW),
        textX, textY, textW, BLACK)
      textY = textY + 10
      maxLines = math.max(1, maxLines - 1)
    end
    for index, line in ipairs(wrappedLines(text, textW, maxLines)) do
      drawText(line, textX, textY + (index - 1) * 9, textW, BLACK)
    end
  end

  local function drawClassic(menu, layout)
    drawClassicBackdrop(layout)
    drawClassicHeader(menu, layout)
    drawClassicRail(menu, layout)
    drawClassicList(menu, layout)
    drawClassicDetails(menu, layout)
  end

  local function draw(menu)
    confineNativeViewport(menu)
    syncInventory(menu)
    local layout = layoutFor(menu)
    menu.rows = layout.rows
    clampList(menu)
    if layout.skin == "classic_pocket" then
      drawClassic(menu, layout)
      gray(WHITE)
      return
    end
    local counts = pocketCounts(menu)
    menu.modernBagIconZones = {}
    menu.modernBagHeaderIconZones = {}
    menu.modernBagHeaderBorderZones = {}
    drawBackdrop(layout)
    drawHeader(menu, layout)
    drawTabs(menu, layout, counts)
    drawWallpaperDivider(layout)
    drawList(menu, layout)
    drawDetails(menu, layout)
    drawFooter(menu, layout)
    gray(WHITE)
  end

  local POCKET_PALETTES = {
    all = "BLUEMON", items = "BROWNMON", medicine = "GREENMON",
    balls = "REDMON", machines = "PURPLEMON", key = "CYANMON",
  }

  local function selectedMenuPalette(game)
    local selected = type(menuColors) == "function" and menuColors() or nil
    local data = game and game.data
    return selected or (data and PaletteFX.pal(data, "MEWMON"))
      or (data and PaletteFX.pal(data, "BLUEMON"))
  end

  local function roundedPaletteZones(zones, colors, x, y, width, height)
    zones[#zones + 1] = {
      colors = colors, x = x + 2, y = y, w = width - 4, h = height,
    }
    zones[#zones + 1] = {
      colors = colors, x = x + 1, y = y + 1,
      w = width - 2, h = height - 2,
    }
    zones[#zones + 1] = {
      colors = colors, x = x, y = y + 2, w = width, h = height - 4,
    }
  end

  -- Complete Modern Bag palette map. This is the sole owner of the parent
  -- screen: selected BetterMenus palette for shared chrome/wallpaper, a
  -- stable list palette, and pocket-specific details/selection accents.
  local function buildParentPaletteZones(menu, game)
    local data = game and game.data
    if not data then return nil end
    local layout = layoutFor(menu)
    local base = selectedMenuPalette(game)
    local stable = PaletteFX.pal(data, "BLUEMON") or base
    if not base or not stable then return nil end

    if type(useStockOgMenuPalette) == "function"
        and useStockOgMenuPalette() then
      return {{
        colors = base, x = 0, y = 0,
        w = layout.width, h = layout.canvasHeight or layout.height,
      }}
    end

    local zones = {{
      colors = base, x = 0, y = 0,
      w = layout.width, h = layout.canvasHeight or layout.height,
    }}
    local paper = type(menuPaperPalette) == "function"
      and menuPaperPalette(game) or nil
    if paper then
      local pockets = pocketsFor(menu)
      local slotW = math.floor(layout.width / #pockets)
      local tileW = math.min(28, slotW - 4)
      for index = 1, #pockets do
        local slotX = (index - 1) * slotW
        local tileX = slotX + math.floor((slotW - tileW) / 2)
        roundedPaletteZones(zones, paper, tileX, layout.tabsY - 1,
          tileW, 18)
      end
    end
    for _, iconZone in ipairs(menu.modernBagHeaderIconZones or {}) do
      zones[#zones + 1] = {
        colors = base,
        x = iconZone.x, y = iconZone.y,
        w = iconZone.w, h = iconZone.h,
      }
    end
    for _, borderZone in ipairs(menu.modernBagHeaderBorderZones or {}) do
      zones[#zones + 1] = {
        colors = base,
        x = borderZone.x, y = borderZone.y,
        w = borderZone.w, h = borderZone.h,
      }
    end
    roundedPaletteZones(zones, base, layout.listX, layout.listY,
      layout.listW, layout.listH)

    local pocket = pocketFor(menu)
    local config = listConfig(menu)
    local accentName = POCKET_PALETTES[pocket.key] or "CYANMON"
    local accent = PaletteFX.pal(data, accentName) or stable
    local details = config and config.modePalette
      and PaletteFX.pal(data, config.modePalette) or accent
    if layout.showDetails then
      roundedPaletteZones(zones, base, layout.detailX, layout.detailY,
        layout.detailW, layout.detailH)
      roundedPaletteZones(zones, paper or details,
        layout.detailX + 2, layout.detailY + 2,
        layout.detailW - 4, layout.detailH - 4)
    end
    local visibleRows = math.min(layout.rows,
      math.max(0, #menu.items - menu.scroll))
    local stackH = visibleRows > 0 and ((visibleRows - 1) * ROW_H + 12) or 0
    local stackY = layout.listY + math.floor((layout.listH - stackH) / 2)
    for row = 1, visibleRows do
      local index = menu.scroll + row
      if not menu.items[index] then break end
      local rowPalette = index == menu.index and base or paper
      if rowPalette then
        roundedPaletteZones(zones, rowPalette,
          layout.listX + 4,
          stackY + (row - 1) * ROW_H,
          layout.listW - 8, 12)
      end
    end
    if menu.scroll > 0 then
      local centerX = layout.listX + math.floor(layout.listW / 2)
      local baseY = stackY - 1
      zones[#zones + 1] = {
        colors = base,
        x = centerX - 2, y = baseY - 3, w = 5, h = 4,
      }
    end
    if menu.scroll + visibleRows < #menu.items then
      local centerX = layout.listX + math.floor(layout.listW / 2)
      zones[#zones + 1] = {
        colors = base,
        x = centerX - 2, y = stackY + stackH + 1, w = 5, h = 4,
      }
    end
    for _, zone in ipairs(menu.modernBagIconZones or {}) do
      zones[#zones + 1] = zone
    end
    return zones
  end

  local function update(menu, dt)
    menu.marquee = (menu.marquee or 0) + 1
    menu.modernBagHeaderFlash = math.min(
      (menu.modernBagHeaderFlash or 0) + 1, 240)
    local layout = layoutFor(menu)
    menu.rows = layout.rows
    clampList(menu)
    syncInventory(menu)
    local input = menu.game.input
    if not (input and input.wasPressed) then
      return menu.modernBagBaseUpdate(menu, dt)
    end
    if input:wasPressed("left") then
      switchPocket(menu, -1)
      return
    elseif input:wasPressed("right") then
      switchPocket(menu, 1)
      return
    end
    -- ListMenu closes an empty list on A as a legacy convenience. Pocket
    -- tabs remain open instead, so the player can continue browsing them.
    if #menu.items == 0 and input:wasPressed("a") then return end
    return menu.modernBagBaseUpdate(menu, dt)
  end

  local function copyParentPaletteZones(owner, game)
    local source = buildParentPaletteZones(owner, game) or {}
    local zones = {}
    for index, zone in ipairs(source) do
      local copy = {}
      for key, value in pairs(zone) do copy[key] = value end
      zones[index] = copy
    end
    return zones
  end

  local function addOverlayPaletteZone(zones, game, x, y, width, height)
    local colors = selectedMenuPalette(game)
    if colors and width and height and width > 0 and height > 0 then
      zones[#zones + 1] = {
        colors = colors, x = x, y = y, w = width, h = height,
      }
    end
    return zones
  end

  local function drawPaletteMappedOverlay(_, drawOverlay)
    local originalDrawBox = Font.drawBox
    Font.drawBox = function(tx, ty, tw, th)
      -- Child boxes stay in the normal four-shade pipeline. The white source
      -- shade maps to the selected BetterMenus menu background, exactly like
      -- the parent header, footer, and wallpaper.
      return originalDrawBox(tx, ty, tw, th, { 255, 255, 255 })
    end
    local ok, err = pcall(drawOverlay)
    Font.drawBox = originalDrawBox
    if not ok then error(err, 0) end
  end

  -- One bridge owns every Modern Bag child. The parent palette map is copied
  -- first on every frame; each child then appends only its own selected-menu
  -- palette rectangle. No child inherits, replaces, shifts, or true-color
  -- masks the parent map.
  local function installOverlayBridge(game)
    local stack = game and game.stack
    if not stack or stack.__modernBagOverlayBridge then return end
    local originalPush = stack.push
    if type(originalPush) ~= "function" then return end
    stack.__modernBagOverlayBridge = true
    stack.push = function(self, state, ...)
      local owner
      for index = #(self.states or {}), 1, -1 do
        local candidate = self.states[index]
        if candidate and candidate.modernBagUI then
          owner = candidate
          break
        end
      end

      local Menu = require("src.ui.Menu")
      if owner and state and getmetatable(state) == Menu then
        state.__modernBagResponsiveOverlay = true
        local layout = type(owner.modernBagLayoutInfo) == "function"
          and owner:modernBagLayoutInfo() or nil
        local width = layout and layout.width or select(1, owner:uiSize())
        local height = layout and (layout.canvasHeight or layout.height)
          or select(2, owner:uiSize())
        state.uiSize = function() return width, height end
        state.holdsUIAnchors = true
        state.tx = math.max(0, math.floor((width / 8 - state.tw) / 2))
        state.ty = math.max(0, math.floor((height / 8 - state.th) / 2))
        state.sgbPalettes = function(_, activeGame)
          return addOverlayPaletteZone(
            copyParentPaletteZones(owner, activeGame), activeGame,
            state.tx * 8, state.ty * 8, state.tw * 8, state.th * 8)
        end
        local baseDraw = state.draw
        state.draw = function(active)
          drawPaletteMappedOverlay(active,
            function() return baseDraw(active) end)
        end
        return originalPush(self, state, ...)
      end

      local TextBox = require("src.render.TextBox")
      if owner and state and getmetatable(state) == TextBox then
        state.__modernBagResponsiveOverlay = true
        state.uiSize = function() return owner:uiSize() end
        state.holdsUIAnchors = true
        local width = owner:uiSize()
        local layout = type(owner.modernBagLayoutInfo) == "function"
          and owner:modernBagLayoutInfo() or nil
        -- Font.drawBox is tile based. Keep a whole-tile frame and center the
        -- remaining one-pixel margins instead of creating a fractional final
        -- tile whose horizontal border cannot reach the right corner.
        state.boxTw = math.max(1, math.floor(width / 8))
        state.boxTx = (width - state.boxTw * 8) / 16
        if layout and layout.footerY then
          state.boxTy = (layout.footerY - state.boxTh * 8) / 8
        end
        state.textX = (state.boxTx + 1) * 8
        state.line1Y = (state.boxTy + 1) * 8
        state.line2Y = (state.boxTy + 3) * 8
        state.sgbPalettes = function(_, activeGame)
          return addOverlayPaletteZone(
            copyParentPaletteZones(owner, activeGame), activeGame,
            state.boxTx * 8, state.boxTy * 8,
            state.boxTw * 8, state.boxTh * 8)
        end
        local baseDraw = state.draw
        state.draw = function(active)
          drawPaletteMappedOverlay(active,
            function() return baseDraw(active) end)
        end
        return originalPush(self, state, ...)
      end

      -- Town Map remains an opaque, centered native-width screen. Tag it so
      -- the final letterbox layer supplies a solid frame outside its viewport.
      local TownMap = require("src.ui.TownMap")
      if owner and state and getmetatable(state) == TownMap then
        state.__modernBagFrameBackdrop = true
        return originalPush(self, state, ...)
      end

      local QuantityBox = require("src.ui.QuantityBox")
      local ChoiceBox = require("src.ui.ChoiceBox")
      local stateType = state and getmetatable(state)
      if owner and state
          and (stateType == QuantityBox or stateType == ChoiceBox)
          and not state.__modernBagResponsiveOverlay then
        state.__modernBagResponsiveOverlay = true
        state.uiSize = function() return owner:uiSize() end
        state.holdsUIAnchors = true

        local function overlayOffset(active)
          local width, height = active:uiSize()
          local offsetX = math.max(0, math.floor((width - SCREEN_W) / 2))
          local offsetY = math.max(0, math.floor((height - SCREEN_H) / 2))
          local QuantityBox = require("src.ui.QuantityBox")
          local ChoiceBox = require("src.ui.ChoiceBox")
          if getmetatable(active) == ChoiceBox then
            local boxW, boxH = active.tw * 8, active.th * 8
            local targetX = math.floor((width - boxW) / 2)
            local targetY = math.floor((height - boxH) / 2)
            active.__modernBagAnchorKind = "center"
            active.__modernBagAnchorX = targetX
            active.__modernBagAnchorY = targetY
            active.__modernBagAnchorW = boxW
            active.__modernBagAnchorH = boxH
            return targetX - active.tx * 8, targetY - active.ty * 8
          end
          if getmetatable(active) ~= QuantityBox
              or type(owner.modernBagLayoutInfo) ~= "function" then
            return offsetX, offsetY
          end

          local layout = owner:modernBagLayoutInfo()
          local priced = active.unitPrice ~= nil
          local threeDigits = not priced and active.max >= 100
          local sourceTX = priced and 7 or (threeDigits and 14 or 15)
          local boxTiles = priced and 13 or (threeDigits and 6 or 5)
          local boxW, boxH = boxTiles * 8, 3 * 8
          local row = math.max(0,
            (owner.index or 1) - (owner.scroll or 0) - 1)
          local selectedTop = layout.listY + 3 + row * ROW_H
          local targetY = selectedTop - math.floor((boxH - 13) / 2)
          local targetX
          if layout.skin ~= "classic_pocket"
              and layout.showDetails and not layout.stacked then
            -- Straddle the seam: a small overlap joins the box to the row,
            -- while most of it opens into the details column.
            targetX = layout.listX + layout.listW - 6
          else
            -- A portrait list has no free column, so replace the selected
            -- row's quantity at its right edge instead of leaving the screen.
            targetX = layout.listX + layout.listW - boxW - 5
          end
          targetX = math.max(0, math.min(width - boxW, targetX))
          targetY = math.max(layout.contentY,
            math.min(layout.footerY - boxH, targetY))
          active.__modernBagAnchorKind = "selection"
          active.__modernBagAnchorX = targetX
          active.__modernBagAnchorY = targetY
          active.__modernBagAnchorW = boxW
          active.__modernBagAnchorH = boxH
          return targetX - sourceTX * 8, targetY - 9 * 8
        end

        local baseDraw = state.draw
        if type(baseDraw) == "function" then
          state.draw = function(active)
            local width, height = active:uiSize()
            local offsetX, offsetY = overlayOffset(active)
            local QuantityBox = require("src.ui.QuantityBox")
            local ChoiceBox = require("src.ui.ChoiceBox")
            local nativePalette = getmetatable(active) == QuantityBox
              or getmetatable(active) == ChoiceBox
            local x, y, w, h
            if active.__modernBagAnchorX then
              x, y = active.__modernBagAnchorX, active.__modernBagAnchorY
              w, h = active.__modernBagAnchorW, active.__modernBagAnchorH
            elseif active.tx and active.ty and active.tw and active.th then
              x, y = active.tx * 8 + offsetX, active.ty * 8 + offsetY
              w, h = active.tw * 8, active.th * 8
            end
            local function drawShifted()
              love.graphics.push("all")
              if active.isOpaque and (offsetX > 0 or offsetY > 0) then
                gray(BLACK)
                love.graphics.rectangle("fill", 0, 0, width, height)
              end
              love.graphics.translate(offsetX, offsetY)
              local ok, err = pcall(baseDraw, active)
              love.graphics.pop()
              if not ok then error(err, 0) end
            end
            if nativePalette then
              drawPaletteMappedOverlay(active, drawShifted)
            else
              drawShifted()
            end
          end
        end

        local basePalettes = state.sgbPalettes
        state.sgbPalettes = function(active, activeGame)
          local zones = copyParentPaletteZones(owner, activeGame)
          local offsetX, offsetY = overlayOffset(active)
          local QuantityBox = require("src.ui.QuantityBox")
          local ChoiceBox = require("src.ui.ChoiceBox")
          if getmetatable(active) == QuantityBox
              or getmetatable(active) == ChoiceBox then
            if active.__modernBagAnchorX then
              return addOverlayPaletteZone(zones, activeGame,
                active.__modernBagAnchorX, active.__modernBagAnchorY,
                active.__modernBagAnchorW, active.__modernBagAnchorH)
            end
            if active.tx and active.ty and active.tw and active.th then
              return addOverlayPaletteZone(zones, activeGame,
                active.tx * 8 + offsetX, active.ty * 8 + offsetY,
                active.tw * 8, active.th * 8)
            end
            return zones
          end
          if active.__modernBagAnchorX then
            return addOverlayPaletteZone(zones, activeGame,
              active.__modernBagAnchorX, active.__modernBagAnchorY,
              active.__modernBagAnchorW, active.__modernBagAnchorH)
          end
          if active.tx and active.ty and active.tw and active.th then
            return addOverlayPaletteZone(zones, activeGame,
              active.tx * 8 + offsetX, active.ty * 8 + offsetY,
              active.tw * 8, active.th * 8)
          end
          if type(basePalettes) == "function" then
            for _, zone in ipairs(basePalettes(active, activeGame) or {}) do
              addOverlayPaletteZone(zones, activeGame,
                (zone.x or 0) + offsetX, (zone.y or 0) + offsetY,
                zone.w or 0, zone.h or 0)
            end
          end
          return zones
        end
      end
      return originalPush(self, state, ...)
    end
  end

  local function installTossPrompts(menu, item)
    local actionMenu = menu.game.stack:top()
    local tossRow
    for _, row in ipairs(actionMenu and actionMenu.items or {}) do
      if tostring(row.label or ""):upper() == "TOSS" then
        tossRow = row
        break
      end
    end
    if not tossRow or type(tossRow.onSelect) ~= "function"
        or actionMenu.__modernBagTossPrompts then
      return
    end
    actionMenu.__modernBagTossPrompts = true
    local chooseToss = tossRow.onSelect
    tossRow.onSelect = function()
      local result = chooseToss()
      local quantity = menu.game.stack:top()
      local QuantityBox = require("src.ui.QuantityBox")
      if getmetatable(quantity) ~= QuantityBox
          or type(quantity.onDone) ~= "function" then
        return result
      end

      menu.modernBagPrompt = Strings("How many?")
      local finishQuantity = quantity.onDone
      quantity.onDone = function(qty)
        if qty then
          menu.modernBagPrompt = Strings("Toss %s?", item.label)
        else
          menu.modernBagPrompt = nil
        end
        local finished = finishQuantity(qty)
        if qty then
          local choice = menu.game.stack:top()
          local ChoiceBox = require("src.ui.ChoiceBox")
          if getmetatable(choice) == ChoiceBox
              and type(choice.onChoose) == "function" then
            local confirm = choice.onChoose
            choice.onChoose = function(yes)
              menu.modernBagPrompt = nil
              return confirm(yes)
            end
          else
            menu.modernBagPrompt = nil
          end
        end
        return finished
      end
      return result
    end
  end

  local function decorateList(menu, config)
    installOverlayBridge(menu.game)
    menu.modernBagListConfig = config or {}
    menu.modernPCUI = true
    menu.modernBagBaseUpdate = menu.update
    menu.modernBagPocket = 1
    menu.modernBagPocketState = {}
    menu.modernBagSwapId = nil
    menu.rows = layoutFor(menu).rows
    menu.draw = draw
    menu.update = update
    menu.sgbPalettes = buildParentPaletteZones
    menu.uiSize = uiSize
    menu.wantsFillScale = function() return true end
    menu.holdsUIAnchors = true
    menu.modernBagUI = true
    menu.modernBagLayout = "pc-pockets"
    menu.modernBagPockets = POCKETS
    menu.modernBagCategoryFor = function(_, id)
      return categoryFor(menu.game, id)
    end
    menu.modernBagLayoutInfo = function() return layoutFor(menu) end
    menu.modernBagSwitchPocket = switchPocket
    menu.modernBagRefresh = rebuildPocket
    rebuildPocket(menu)
    return menu
  end

  return {
    decorateList = decorateList,
    new = function(game, opts)
      installOverlayBridge(game)
      local upstream = compatibility.kantoReforged
        and compatibility.upstreamBagScreen
      local menu = upstream and upstream.new(game, opts)
        or BagMenu.new(game, opts)
      local externalController = upstream ~= nil
        and type(menu.__pocketIndex) == "number"
        and type(menu.__pocketIds) == "table"
        and type(menu.gen1ModernUi) == "table"
        and type(menu.gen1ModernUi.switchPocket) == "function"
      local baseChoose = menu.onChoose
      menu.modernBagBaseUpdate = menu.update
      menu.modernBagPocket = 1
      menu.modernBagPocketState = {}
      menu.modernBagSwapId = nil
      menu.modernBagExternalController = externalController
      menu.modernBagPockets = externalController and KANTO_POCKETS or POCKETS
      syncExternalPocketIndex(menu)
      menu.rows = layoutFor(menu).rows

      if not externalController then
        menu.onSelectKey = function(item, list)
          reorder(list, item)
        end
      end
      menu.onChoose = function(item, list)
        if not externalController and list.modernBagSwapId then
          finishSwap(list, item and item.value)
          return
        end
        local result = baseChoose(item, list)
        if item and item.value then installTossPrompts(list, item) end
        return result
      end

      menu.draw = draw
      menu.update = update
      menu.sgbPalettes = buildParentPaletteZones
      menu.uiSize = uiSize
      menu.wantsFillScale = function() return true end
      -- The responsive Bag is one composed surface. In DYNAMIC UI mode a
      -- TextBox normally docks itself to the window edge, but its 160px
      -- source rect is declared in classic coordinates while this screen is
      -- wider. The renderer would then cut out the wrong canvas region and
      -- reassemble part of the Bag as dialogue (# wide Bag text seam).
      -- Battles solve the same composition problem by holding UI anchors;
      -- keep Bag messages (item failures, toss confirmations, etc.) inside
      -- this surface as well.
      menu.holdsUIAnchors = true
      menu.modernBagUI = true
      menu.modernBagLayout = "pockets"
      menu.modernBagCategoryFor = function(_, id) return categoryFor(game, id) end
      menu.modernBagLayoutInfo = function() return layoutFor(menu) end
      menu.modernBagSwitchPocket = switchPocket
      menu.modernBagRefresh = rebuildPocket
      rebuildPocket(menu)
      return menu
    end,
  }
end

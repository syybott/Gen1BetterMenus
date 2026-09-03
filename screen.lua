-- A single party-and-box workspace inspired by the storage screens in newer
-- Pokémon games. The engine's compact list-shaped Gen 1 saves stay intact;
-- this screen is only a controller and presentation layer over those lists.
return function(mod, genderExports, compatibility, menuColors,
    useStockOgMenuPalette, menuPaper, rawPaletteCopy)
  compatibility = compatibility or {}
  local Assets = require("src.render.Assets")
  local Boxes = require("src.pokemon.Boxes")
  local Font = require("src.render.Font")
  local Growth = require("src.pokemon.Growth")
  local HudTiles = require("src.render.HudTiles")
  local Logger = require("src.core.Logger")
  local PaletteFX = require("src.render.PaletteFX")
  local Party = require("src.pokemon.Party")
  local PartyMenu = require("src.ui.PartyMenu")
  local Renderer = require("src.render.Renderer")
  local Runtime = require("src.mods.Runtime")
  local Sound = require("src.core.Sound")
  local Sprites = require("src.pokemon.Sprites")
  local Status = require("src.battle.Status")
  local Stats = require("src.pokemon.Stats")
  local Strings = require("src.core.Strings")
  local TextBox = require("src.render.TextBox")
  local Theme = require("src.ui.Theme")
  local TypeChart = require("src.battle.TypeChart")

  local SCREEN_H = 144
  local HEADER_H = 14
  local FOOTER_Y = 135
  local WHITE = 1
  local LIGHT = 170 / 255
  local DARK = 85 / 255
  local BLACK = 0

  local TYPE_BASE = {
    NORMAL = { 184, 185, 171 }, FIGHTING = { 174, 91, 75 },
    FLYING = { 117, 148, 202 }, POISON = { 161, 91, 151 },
    GROUND = { 207, 178, 98 }, ROCK = { 183, 168, 109 },
    BUG = { 175, 186, 66 }, GHOST = { 101, 104, 173 },
    FIRE = { 233, 84, 54 }, WATER = { 99, 145, 205 },
    GRASS = { 141, 194, 102 }, ELECTRIC = { 247, 205, 85 },
    PSYCHIC = { 236, 99, 145 }, PSYCHIC_TYPE = { 236, 99, 145 },
    ICE = { 147, 213, 245 }, DRAGON = { 99, 102, 173 },
    DARK = { 114, 86, 74 }, FAIRY = { 218, 176, 212 },
    STEEL = { 164, 163, 179 },
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
  local battleSpriteCache = setmetatable({}, { __mode = "k" })
  local rawTypePalettes = setmetatable({}, { __mode = "k" })
  local xpMarkImage

  local TYPE_ABBREVIATIONS = {
    NORMAL = "NRM", FIRE = "FIR", FLYING = "FLY", PSYCHIC = "PSY",
    PSYCHIC_TYPE = "PSY", WATER = "WTR", GROUND = "GRD",
    STEEL = "STL", POISON = "PSN", DRAGON = "DRA", FIGHTING = "FGT",
    DARK = "DRK", ICE = "ICE", ELECTRIC = "ELE", ROCK = "RCK",
    GRASS = "GRS", BUG = "BUG", GHOST = "GHO", FAIRY = "FAY",
  }

  local TINY_GLYPHS = {
    A = { "010", "101", "111", "101", "101" },
    B = { "110", "101", "110", "101", "110" },
    C = { "011", "100", "100", "100", "011" },
    D = { "110", "101", "101", "101", "110" },
    E = { "111", "100", "110", "100", "111" },
    F = { "111", "100", "110", "100", "100" },
    G = { "011", "100", "101", "101", "011" },
    H = { "101", "101", "111", "101", "101" },
    I = { "111", "010", "010", "010", "111" },
    J = { "001", "001", "001", "101", "010" },
    K = { "101", "101", "110", "101", "101" },
    L = { "100", "100", "100", "100", "111" },
    M = { "101", "111", "111", "101", "101" },
    N = { "101", "111", "111", "111", "101" },
    O = { "010", "101", "101", "101", "010" },
    P = { "110", "101", "110", "100", "100" },
    Q = { "010", "101", "101", "111", "011" },
    R = { "110", "101", "110", "101", "101" },
    S = { "011", "100", "010", "001", "110" },
    T = { "111", "010", "010", "010", "010" },
    U = { "101", "101", "101", "101", "111" },
    V = { "101", "101", "101", "101", "010" },
    W = { "101", "101", "111", "111", "101" },
    X = { "101", "101", "010", "101", "101" },
    Y = { "101", "101", "010", "010", "010" },
    Z = { "111", "001", "010", "100", "111" },
    ["0"] = { "111", "101", "101", "101", "111" },
    ["1"] = { "010", "110", "010", "010", "111" },
    ["2"] = { "111", "001", "111", "100", "111" },
    ["3"] = { "111", "001", "111", "001", "111" },
    ["4"] = { "101", "101", "111", "001", "001" },
    ["5"] = { "111", "100", "111", "001", "111" },
    ["6"] = { "111", "100", "111", "101", "111" },
    ["7"] = { "111", "001", "010", "010", "010" },
    ["8"] = { "111", "101", "111", "101", "111" },
    ["9"] = { "111", "101", "111", "001", "111" },
    ["-"] = { "000", "000", "111", "000", "000" },
    ["/"] = { "001", "001", "010", "100", "100" },
    ["%"] = { "101", "001", "010", "100", "101" },
    ["("] = { "011", "100", "100", "100", "011" },
    [")"] = { "110", "001", "001", "001", "110" },
    [":"] = { "000", "010", "000", "010", "000" },
    ["'"] = { "010", "010", "000", "000", "000" },
    [" "] = { "000", "000", "000", "000", "000" },
  }

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

  -- Match Modern Bag's symmetric hard-pixel rounded geometry. Three stacked
  -- rectangles produce identical two-pixel steps at all four corners.
  local function pixelRoundFill(x, y, width, height)
    x, y = math.floor(x), math.floor(y)
    width, height = math.floor(width), math.floor(height)
    love.graphics.rectangle("fill", x + 2, y, width - 4, height)
    love.graphics.rectangle("fill", x + 1, y + 1, width - 2, height - 2)
    love.graphics.rectangle("fill", x, y + 2, width, height - 4)
  end

  local SELECTOR_ON_SECONDS = 0.700
  local SELECTOR_OFF_SECONDS = 0.250
  local SELECTOR_PERIOD_SECONDS = SELECTOR_ON_SECONDS + SELECTOR_OFF_SECONDS

  local function selectorVisible(screen)
    local elapsed = tonumber(screen and screen.selectorBlinkElapsed) or 0
    return elapsed % SELECTOR_PERIOD_SECONDS < SELECTOR_ON_SECONDS
  end

  -- One-pixel rounded outline matching pixelRoundFill(rect) minus
  -- pixelRoundFill(rect inset by one). The stepped corner pixels are kept as
  -- separate runs so only the selector ink, never the slot interior, is
  -- protected from menu-palette conversion.
  local function selectorOutlineRuns(rect)
    local x, y = math.floor(rect.x), math.floor(rect.y)
    local w, h = math.floor(rect.w), math.floor(rect.h)
    return {
      { x = x + 2, y = y,         w = w - 4, h = 1 },
      { x = x + 1, y = y + 1,     w = 2,     h = 1 },
      { x = x + w - 3, y = y + 1, w = 2,     h = 1 },
      { x = x, y = y + 2,         w = 2,     h = 1 },
      { x = x + w - 2, y = y + 2, w = 2,     h = 1 },
      { x = x, y = y + 3,         w = 1,     h = h - 6 },
      { x = x + w - 1, y = y + 3, w = 1,     h = h - 6 },
      { x = x, y = y + h - 3,     w = 2,     h = 1 },
      { x = x + w - 2, y = y + h - 3, w = 2, h = 1 },
      { x = x + 1, y = y + h - 2, w = 2,     h = 1 },
      { x = x + w - 3, y = y + h - 2, w = 2, h = 1 },
      { x = x + 2, y = y + h - 1, w = w - 4, h = 1 },
    }
  end

  local function protectBlackSelector(trueColorRegions, rect)
    for _, run in ipairs(selectorOutlineRuns(rect)) do
      trueColorRegions[#trueColorRegions + 1] = run
    end
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

  local function roundedPaletteFrame(zones, border, face, rect, thickness)
    roundedPaletteZones(zones, border, rect.x, rect.y, rect.w, rect.h)
    thickness = thickness or 1
    roundedPaletteZones(zones, face,
      rect.x + thickness, rect.y + thickness,
      rect.w - thickness * 2, rect.h - thickness * 2)
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
        detail = { x = 2, y = 106, w = width - 4, h = 29 },
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
      detail = { x = width - detailW - 3, y = 17, w = detailW, h = 115 },
    }
  end

  local function slotRect(layout, region, index)
    local panel = layout[region]
    local zero = index - 1
    local column = zero % panel.cols
    local row = math.floor(zero / panel.cols)
    local innerW, innerH = panel.w - 6, panel.h - 6
    local x1 = panel.x + 3 + math.floor(column * innerW / panel.cols)
    local x2 = panel.x + 3 + math.floor((column + 1) * innerW / panel.cols)
    local y1 = panel.y + 3 + math.floor(row * innerH / panel.rows)
    local y2 = panel.y + 3 + math.floor((row + 1) * innerH / panel.rows)
    return { x = x1, y = y1, w = x2 - x1, h = y2 - y1 }
  end

  local function panelFrame(panel, faceShade)
    gray(DARK)
    pixelRoundFill(panel.x, panel.y, panel.w, panel.h)
    gray(faceShade or WHITE)
    pixelRoundFill(panel.x + 2, panel.y + 2,
      panel.w - 4, panel.h - 4)
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

  local function paletteForType(value)
    return TYPE_PALETTES[tostring(value or "NORMAL"):upper()]
      or TYPE_PALETTES.NORMAL
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
    local oldRegion = screen.region
    local oldIndex = currentIndex(screen)
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

    if screen.held
        and (screen.region ~= oldRegion or currentIndex(screen) ~= oldIndex) then
      if screen.region == "party" then
        if oldRegion ~= "party" then
          screen.leftPaneMode = "party"
          screen.leftPaneManual = false
        end
      elseif not screen.leftPaneManual then
        screen.leftPaneMode = "detail"
      end
    end
  end

  local function resetMoveView(screen)
    screen.leftPaneMode = "party"
    screen.leftPaneManual = false
    screen.detailPage = 1
  end

  local function deposited(screen, mon)
    require("src.world.PikachuFollower")
      .modifyHappiness(screen.game.save, "DEPOSITED", mon)
  end

  local function finishMove(screen, targetList, targetIndex, targetCapacity)
    local held = screen.held
    if not held or held.sourceList[held.sourceIndex] ~= held.mon then
      screen.held = nil
      screen.selectorBlinkElapsed = 0
      resetMoveView(screen)
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
        screen.selectorBlinkElapsed = 0
        resetMoveView(screen)
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
    screen.selectorBlinkElapsed = 0
    resetMoveView(screen)
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
    screen.selectorBlinkElapsed = 0
    resetMoveView(screen)
    screen.status = nil
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
      items[#items + 1] = { label = Strings("MOVE"), action = "move" }
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
      local moveEntry
      local ordered = {}
      for _, entry in ipairs(items) do
        if entry.action == "move" then
          moveEntry = moveEntry or entry
        elseif entry.action ~= "summary" then
          ordered[#ordered + 1] = entry
        end
      end
      if moveEntry then table.insert(ordered, 1, moveEntry) end
      items = ordered
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
    elseif action == "move" then
      pickOrDrop(screen)
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

  local function leftPaneShowsDetails(screen)
    return screen.held ~= nil and screen.leftPaneMode == "detail"
  end

  local function paneMons(screen)
    local right = screen.held and screen.held.mon or selected(screen)
    local left = leftPaneShowsDetails(screen) and selected(screen) or nil
    return left, right
  end

  local function monHasMove(mon, slot)
    return mon and mon.moves and mon.moves[slot] ~= nil
  end

  local function advanceDetailPage(screen)
    local left, right = paneMons(screen)
    local page = screen.detailPage or 1
    for _ = 1, 8 do
      page = page % 8 + 1
      if page <= 4
          or monHasMove(left, page - 4)
          or monHasMove(right, page - 4) then
        screen.detailPage = page
        return
      end
    end
    screen.detailPage = 1
  end

  function PC:update(_dt)
    self.blink = ((self.blink or 0) + 1) % 320
	local dt = tonumber(_dt)
	if not dt or dt <= 0 then dt = 1 / 60 end
	self.selectorBlinkElapsed =
	  ((self.selectorBlinkElapsed or 0) + dt) % SELECTOR_PERIOD_SECONDS
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
		self.selectorBlinkElapsed = 0
        return
      end
    end

    if input:wasPressed("a") then
      if self.held then
        pickOrDrop(self)
      else
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
    elseif input:wasPressed("b") then
      if self.held then
        self.held = nil
        self.selectorBlinkElapsed = 0
        resetMoveView(self)
        self.status = Strings("Move cancelled.")
      else
        self.game.stack:pop()
      end
      play(self, "Press_AB")
    elseif input:wasPressed("select") then
      if self.held then
        self.leftPaneMode = leftPaneShowsDetails(self) and "party" or "detail"
        self.leftPaneManual = true
        self.status = nil
        play(self, "Press_AB")
      else
        beginBoxSwitcher(self)
      end
    elseif input:wasPressed("start") then
      self.status = nil
      play(self, "Press_AB")
      advanceDetailPage(self)
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
    local box = Boxes.active(screen.game.save)
    local label = layout.compact
      and Strings("BOX%02d", screen.game.save.currentBox)
      or Strings("BOX%02d %02d/%02d",
        screen.game.save.currentBox, #box, Boxes.CAPACITY)
    local selectorW = math.min(layout.box.w - 2, Font.width(label) + 16)
    local selectorX = layout.compact and layout.box.x + 1
      or math.floor(layout.box.x + (layout.box.w - selectorW) / 2)
    local selectorY = 0
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
        love.graphics.translate(x + 8, 3)
        love.graphics.scale(-1, 1)
        Font.drawCode(Theme.cursor, 0, 0)
      else
        Font.drawCode(Theme.cursor, x, 3)
      end
      love.graphics.pop()
    end
    drawArrow(selectorX, true)
    drawArrow(selectorX + selectorW - 8, false)
    drawCentered(label, selectorX + selectorW / 2, 3,
      selectorW - 16, WHITE)

    if layout.compact then
      drawText(Strings("PARTY"), 4, 3, 40, WHITE)
      drawRight(("%02d/%02d"):format(#box, Boxes.CAPACITY),
        layout.width - 4, 3, 48, WHITE)
    else
      drawCentered(Strings("PARTY"), layout.party.x + layout.party.w / 2,
        3, layout.party.w - 8, WHITE)
      drawCentered(Strings("DETAILS"),
        layout.detail.x + layout.detail.w / 2, 3,
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

  local function genderWidth(mon)
    if not (genderExports and type(genderExports.genderOf) == "function"
        and type(genderExports.symbol) == "function") then
      return 0
    end
    local okGender, gender = pcall(genderExports.genderOf, mon)
    if not okGender then return 0 end
    local okSymbol, symbol = pcall(genderExports.symbol, gender)
    return okSymbol and type(symbol) == "string" and symbol ~= "" and 9 or 0
  end

  local function isHeldOrigin(screen, region, list, index)
    local held = screen.held
    if not held or held.sourceList ~= list or held.sourceIndex ~= index then
      return false
    end
    if region ~= "box" then return true end
    return held.sourceBox == screen.game.save.currentBox
  end

  local function cleanTinyText(text)
    return tostring(text or ""):gsub("%.", ""):upper()
  end

  local function tinyTextWidth(text)
    local length = #cleanTinyText(text)
    return length > 0 and length * 4 - 1 or 0
  end

  local function tinyTextFit(text, maxWidth)
    text = cleanTinyText(text)
    local count = math.max(0, math.floor((math.floor(maxWidth or 0) + 1) / 4))
    return text:sub(1, count)
  end

  local function drawTinyText(text, x, y, shade)
    text = cleanTinyText(text)
    gray(shade)
    local cursor = math.floor(x)
    y = math.floor(y)
    for character in tostring(text):gmatch(".") do
      local glyph = TINY_GLYPHS[character]
      if glyph then
        for row = 1, 5 do
          for column = 1, 3 do
            if glyph[row]:sub(column, column) == "1" then
              love.graphics.rectangle("fill", cursor + column - 1,
                y + row - 1, 1, 1)
            end
          end
        end
      end
      cursor = cursor + 4
    end
    return tinyTextWidth(text)
  end

  local function drawTinyCentered(text, centerX, y, maxWidth, shade)
    text = tinyTextFit(text, maxWidth)
    local width = tinyTextWidth(text)
    drawTinyText(text, math.floor(centerX - width / 2), y, shade)
  end

  -- A fixed 4x6 face keeps every ten-character nickname on even the narrowest
  -- data pane while remaining visibly larger than the 3x5 metadata face.
  local function mediumTextWidth(text)
    local length = #cleanTinyText(text)
    return length > 0 and length * 5 - 1 or 0
  end

  local function mediumTextFit(text, maxWidth)
    text = cleanTinyText(text)
    local count = math.max(0, math.floor((math.floor(maxWidth or 0) + 1) / 5))
    return text:sub(1, count)
  end

  local function drawMediumText(text, x, y, shade)
    text = cleanTinyText(text)
    gray(shade)
    local cursor = math.floor(x)
    y = math.floor(y)
    for character in text:gmatch(".") do
      local glyph = TINY_GLYPHS[character]
      if glyph then
        for dy = 0, 5 do
          local sourceRow = math.floor(dy * 5 / 6) + 1
          for dx = 0, 3 do
            local sourceColumn = math.floor(dx * 3 / 4) + 1
            if glyph[sourceRow]:sub(sourceColumn, sourceColumn) == "1" then
              love.graphics.rectangle("fill", cursor + dx, y + dy, 1, 1)
            end
          end
        end
      end
      cursor = cursor + 5
    end
    return mediumTextWidth(text)
  end

  local function drawMediumCentered(text, centerX, y, maxWidth, shade)
    text = mediumTextFit(text, maxWidth)
    drawMediumText(text, math.floor(centerX - mediumTextWidth(text) / 2),
      y, shade)
  end

  local function ownedPalette(palette)
    if type(rawPaletteCopy) ~= "function" or type(palette) ~= "table" then
      return palette
    end
    local owned = rawTypePalettes[palette]
    if not owned then
      owned = rawPaletteCopy(palette)
      rawTypePalettes[palette] = owned
    end
    return owned
  end

  local function ownedTypePalette(screen, mon)
    return ownedPalette(monPalette(screen, mon))
  end

  local function paletteLuminance(color)
    if type(color) ~= "table" then return -math.huge end
    return (tonumber(color[1]) or 0) * 0.2126
      + (tonumber(color[2]) or 0) * 0.7152
      + (tonumber(color[3]) or 0) * 0.0722
  end

  -- Data panes always use paper as shade one and light-to-dark ink as shades
  -- two through four. Rebuilding by luminance makes their words independent
  -- of the global inverse option without changing any type-owned border ramp.
  local function lockedDataPaper(game)
    local source = type(menuColors) == "function" and menuColors(game) or nil
    local paper = type(menuPaper) == "function" and menuPaper(game) or nil
    if type(source) ~= "table" then return paper end
    local shades = {}
    for index = 1, 4 do
      if type(source[index]) == "table" then shades[#shades + 1] = source[index] end
    end
    table.sort(shades, function(a, b)
      return paletteLuminance(a) > paletteLuminance(b)
    end)
    if #shades < 4 then return paper or source end
    local locked = {
      paper and paper[1] or shades[1], shades[2], shades[3], shades[4],
    }
    return type(rawPaletteCopy) == "function" and rawPaletteCopy(locked) or locked
  end

  local function drawTypeMatchedIcon(screen, mon, x, y, animate, scale,
      trueColorRegions, background)
    local palette = ownedTypePalette(screen, mon)
    local shader = palette and PaletteFX.shader()
    local discardedRegions = {}
    local target = 16 * scale
    fillTrueColorBacking(background, x, y, target, target)
    love.graphics.push("all")
    if shader then
      PaletteFX.sendColors(shader, palette)
      love.graphics.setShader(shader)
    end
    if isHgssIcon(screen, mon) then
      local entry = iconEntry(screen, mon)
      if not drawFittedHgssIcon(screen, mon, entry, x, y,
          animate, target, discardedRegions) then
        drawSharedIcon(screen, mon, x, y, animate,
          target / 32, discardedRegions)
      end
    else
      drawSharedIcon(screen, mon, x, y, animate, scale, discardedRegions)
    end
    love.graphics.pop()
    trueColorRegions[#trueColorRegions + 1] = {
      x = x, y = y, w = target, h = target,
    }
  end

  local function drawSlot(screen, layout, region, list, index,
      trueColorRegions)
    local rect = slotRect(layout, region, index)
    local mon = list[index]
    local chosen = screen.region == region and currentIndex(screen) == index
    local origin = isHeldOrigin(screen, region, list, index)
    local showSelector = chosen and selectorVisible(screen)

    if showSelector then
      gray(BLACK)
      pixelRoundFill(rect.x, rect.y, rect.w, rect.h)
      gray(WHITE)
      pixelRoundFill(rect.x + 1, rect.y + 1,
        rect.w - 2, rect.h - 2)
      protectBlackSelector(trueColorRegions, rect)
    elseif mon then
      gray(DARK)
      pixelRoundFill(rect.x, rect.y, rect.w, rect.h)
      gray(WHITE)
      pixelRoundFill(rect.x + 1, rect.y + 1,
        rect.w - 2, rect.h - 2)
    else
      gray(DARK)
      pixelRoundFill(rect.x + 2, rect.y + 2,
        rect.w - 4, rect.h - 4)
      gray(WHITE)
      pixelRoundFill(rect.x + 3, rect.y + 3,
        rect.w - 6, rect.h - 6)
    end

    if mon then
      local paper = type(menuPaper) == "function" and menuPaper(screen.game)
        or (type(menuColors) == "function" and menuColors())
      local face = colorFromPalette(paper or monPalette(screen, mon), 1)
      if region == "party" and not layout.compact then
        drawTypeMatchedIcon(screen, mon, rect.x + 3,
          rect.y + math.max(1, math.floor((rect.h - 16) / 2) - 1),
          iconAnimationEnabled(screen) and chosen, 1,
          trueColorRegions, face)
        local textX = rect.x + 23
        local textW = rect.w - 26
        local blockY = rect.y + math.floor((rect.h - 11) / 2)
        drawTinyText(tinyTextFit(monName(screen, mon), textW),
          textX, blockY, BLACK)
        drawTinyText("L" .. tostring(math.max(1, math.min(100,
          mon.level or 1))), textX, blockY + 6, BLACK)
      else
        drawTypeMatchedIcon(screen, mon,
          rect.x + math.floor((rect.w - 16) / 2),
          rect.y + math.floor((rect.h - 16) / 2),
          iconAnimationEnabled(screen) and chosen, 1,
          trueColorRegions, face)
      end
    end

    if origin then
      gray(BLACK)
      love.graphics.line(rect.x + 3, rect.y + 3,
        rect.x + rect.w - 4, rect.y + rect.h - 4)
      love.graphics.line(rect.x + rect.w - 4, rect.y + 3,
        rect.x + 3, rect.y + rect.h - 4)
    end
  end

  local function opaqueRuns(path)
    if not path then return nil end
    local ok, data = pcall(Assets.imageData, path)
    if not ok or not data then return nil end
    local width, height = data:getDimensions()
    local runs = {}
    for y = 0, height - 1 do
      local start
      for x = 0, width - 1 do
        local _, _, _, alpha = data:getPixel(x, y)
        local opaque = (alpha or 0) > 0.01
        if opaque and not start then start = x end
        if start and (not opaque or x == width - 1) then
          local finish = opaque and x or x - 1
          runs[#runs + 1] = { x = start, y = y, w = finish - start + 1 }
          start = nil
        end
      end
    end
    return runs
  end

  local function battleSpriteFor(screen, mon)
    local cached = battleSpriteCache[mon]
    if cached then return cached.image, cached.trueColor, cached.runs end
    local path, trueColor = Sprites.path(screen.game.data, mon.species,
      "front", { mon = mon, kind = "battle" })
    local ok, image = false, nil
    if path then ok, image = pcall(Assets.image, path) end
    cached = { image = ok and image or false, trueColor = trueColor == true,
      runs = opaqueRuns(path) }
    battleSpriteCache[mon] = cached
    return cached.image or nil, cached.trueColor, cached.runs
  end

  local function battleSpriteRect(panel, image, availableH, top)
    if not image then return nil end
    local width, height = image:getDimensions()
    local availableW = panel.w - 8
    availableH = availableH or 48
    local scale = math.min(1, availableW / width, availableH / height)
    local drawW, drawH = width * scale, height * scale
    return {
      x = math.floor(panel.x + (panel.w - drawW) / 2),
      y = math.floor(panel.y + (top or 16) + (availableH - drawH) / 2),
      w = drawW, h = drawH, scale = scale,
    }
  end

  local function getXpMarkImage()
    if xpMarkImage ~= nil then return xpMarkImage or nil end
    local ok, image = pcall(love.graphics.newImage,
      mod.path .. "/assets/xp_x.png")
    if not ok or not image then
      xpMarkImage = false
      return nil
    end
    image:setFilter("nearest", "nearest")
    xpMarkImage = image
    return image
  end

  local function drawXpLabel(x, y)
    love.graphics.setColor(1, 1, 1, 1)
    HudTiles.tile(0x71, x, y)
    local sx, sy, sw, sh = love.graphics.getScissor()
    love.graphics.setScissor(x + 8, y, 6, 8)
    HudTiles.tile(0x62, x + 8, y)
    if sx then
      love.graphics.setScissor(sx, sy, sw, sh)
    else
      love.graphics.setScissor()
    end
    gray(WHITE)
    love.graphics.rectangle("fill", x + 1, y + 2, 4, 4)
    local image = getXpMarkImage()
    if image then
      gray(BLACK)
      love.graphics.draw(image, x + 1, y + 2)
    end
  end

  local function drawHpLabel(x, y)
    love.graphics.setColor(1, 1, 1, 1)
    HudTiles.tile(0x71, x, y)
    local sx, sy, sw, sh = love.graphics.getScissor()
    love.graphics.setScissor(x + 8, y, 6, 8)
    HudTiles.tile(0x62, x + 8, y)
    if sx then
      love.graphics.setScissor(sx, sy, sw, sh)
    else
      love.graphics.setScissor()
    end
  end

  local function drawMeter(labelDrawer, ratio, fillColor, panel, y,
      trueColorRegions)
    local x = panel.x + 4
    local barX = x + 15
    local barWidth = math.max(8, panel.w - 25)
    labelDrawer(x, y)
    gray(BLACK)
    love.graphics.rectangle("fill", barX, y + 2, barWidth, 1)
    love.graphics.rectangle("fill", barX - 1, y + 3, 1, 2)
    love.graphics.rectangle("fill", barX + barWidth, y + 3, 1, 2)
    love.graphics.rectangle("fill", barX, y + 5, barWidth, 1)
    local clampedRatio = math.max(0, math.min(1, ratio))
    local fillWidth = clampedRatio > 0
      and math.max(1, math.floor(barWidth * clampedRatio)) or 0
    if fillWidth > 0 then
      love.graphics.setColor(fillColor[1], fillColor[2], fillColor[3], 1)
      love.graphics.rectangle("fill", barX, y + 3, fillWidth, 2)
      trueColorRegions[#trueColorRegions + 1] = {
        x = barX, y = y + 3, w = fillWidth, h = 2,
      }
    end
  end

  local function hpFillColor(screen, ratio)
    if ratio >= 27 / 48 then return { 0, 189 / 255, 0 } end
    local name = ratio >= 27 / 48 and "GREENBAR"
      or ratio >= 10 / 48 and "YELLOWBAR" or "REDBAR"
    local palette = PaletteFX.pal(screen.game.data, name)
    local color = palette and palette[3] or { 0, 189, 0 }
    return { color[1] / 255, color[2] / 255, color[3] / 255 }
  end

  local function drawFittedHPBar(screen, mon, panel, y, trueColorRegions)
    local maxHP = mon.stats and mon.stats.hp or 1
    local ratio = math.max(0, math.min(1, (mon.hp or 0) / math.max(1, maxHP)))
    drawMeter(drawHpLabel, ratio, hpFillColor(screen, ratio), panel, y,
      trueColorRegions)
  end

  local function drawXpBar(ratio, panel, y, trueColorRegions)
    drawMeter(drawXpLabel, ratio, { 0.32, 0.68, 0.96 }, panel, y,
      trueColorRegions)
  end

  local function typeAbbreviation(value)
    local key = tostring(value or ""):upper()
    return TYPE_ABBREVIATIONS[key] or key:sub(1, 3)
  end

  local function detailTypeBadges(panel, types, hasGender)
    local badges = {}
    local left = panel.x + 3 + (hasGender and 9 or 0)
    local right = panel.x + panel.w - 3
    local cursorX = right
    local y = panel.y + 3
    for _, value in ipairs(types or {}) do
      local text = typeAbbreviation(value)
      local width = tinyTextWidth(text) + 6
      if cursorX - width < left then
        cursorX = right
        y = y + 10
      end
      local rect = { x = cursorX - width, y = y, w = width, h = 9 }
      badges[#badges + 1] = {
        value = value, text = text, rect = rect,
        palette = ownedPalette(paletteForType(value)),
      }
      cursorX = rect.x - 1
    end
    local genderPosition
    if hasGender then
      local firstRowLeft = right
      for _, badge in ipairs(badges) do
        if badge.rect.y == panel.y + 3 then
          firstRowLeft = math.min(firstRowLeft, badge.rect.x)
        end
      end
      genderPosition = {
        x = firstRowLeft - 9,
        y = panel.y + 3,
      }
    end
    return badges, genderPosition
  end

  local function drawTypeBadges(badges)
    for _, badge in ipairs(badges) do
      local rect = badge.rect
      gray(DARK)
      pixelRoundFill(rect.x, rect.y, rect.w, rect.h)
      gray(WHITE)
      pixelRoundFill(rect.x + 1, rect.y + 1, rect.w - 2, rect.h - 2)
      drawTinyCentered(badge.text, rect.x + rect.w / 2,
        rect.y + 2, rect.w - 2, BLACK)
    end
  end

  local function detailFaceFor(screen, mon)
    local paper = lockedDataPaper(screen.game)
    return colorFromPalette(paper or monPalette(screen, mon), 1)
  end

  local function drawBattleSprite(screen, panel, mon, trueColorRegions,
      availableH, top)
    local image, trueColor, runs = battleSpriteFor(screen, mon)
    local rect = battleSpriteRect(panel, image, availableH, top)
    if not (image and rect) then return end
    local face = detailFaceFor(screen, mon)
    if not (runs and runs[1]) then
      fillTrueColorBacking(face, rect.x, rect.y, rect.w, rect.h)
    end
    love.graphics.setColor(1, 1, 1, 1)
    local shader
    if not trueColor then
      local palette = PaletteFX.monPal(screen.game.data, mon.species)
        or monPalette(screen, mon)
      shader = palette and PaletteFX.shader()
      if shader then
        PaletteFX.sendColors(shader, palette)
        love.graphics.setShader(shader)
      end
    end
    love.graphics.draw(image, rect.x, rect.y, 0, rect.scale, rect.scale)
    if shader then love.graphics.setShader() end
    if runs and runs[1] then
      for _, run in ipairs(runs) do
        trueColorRegions[#trueColorRegions + 1] = {
          x = rect.x + run.x * rect.scale,
          y = rect.y + run.y * rect.scale,
          w = math.max(1, run.w * rect.scale),
          h = math.max(1, rect.scale),
        }
      end
    else
      trueColorRegions[#trueColorRegions + 1] = rect
    end
  end

  local function drawDataHeader(screen, panel, mon, trueColorRegions)
    local def = screen.game.data.pokemon[mon.species] or {}
    local hasGender = genderWidth(mon) > 0
    local badges, genderPosition = detailTypeBadges(
      panel, def.types or {}, hasGender)
    if mon.status then
      drawTinyText(Status.hudLabelFor(screen.game.data.statuses, mon.status),
        panel.x + 4, panel.y + 5, BLACK)
    end
    if genderPosition then
      drawGenderGlyph(mon, genderPosition.x, genderPosition.y,
        detailFaceFor(screen, mon), trueColorRegions)
    end
    drawTypeBadges(badges)
    return def
  end

  local function moveInfo(screen, mon, slot)
    local move = mon and mon.moves and mon.moves[slot]
    return move, move and screen.game.data.moves[move.id] or nil
  end

  local function maxMovePP(move, def)
    if not (move and def) then return 0 end
    local base = tonumber(def.pp) or 0
    return base + (move.ppUps or 0) * math.floor(base / 5)
  end

  local function moveClass(def)
    if not def then return "---" end
    if tonumber(def.power) == 0 then return "STATUS" end
    return tostring(def.category or TypeChart.category(def.type) or "---"):upper()
  end

  local function drawOverview(screen, panel, mon, location, def,
      trueColorRegions)
    drawBattleSprite(screen, panel, mon, trueColorRegions, 48, 16)
    local infoY = panel.y + 66
    drawMediumCentered(monName(screen, mon), panel.x + panel.w / 2,
      infoY, panel.w - 8, BLACK)
    drawTinyCentered("LVL " .. tostring(mon.level or 1),
      panel.x + panel.w / 2, infoY + 8, panel.w - 8, BLACK)
    drawTinyCentered(location, panel.x + panel.w / 2,
      infoY + 15, panel.w - 8, BLACK)
    local meterY = panel.y + panel.h - 18
    drawFittedHPBar(screen, mon, panel, meterY, trueColorRegions)
    local level = math.max(1, math.min(100, mon.level or 1))
    local rates = screen.game.data.growth_rates
    local current = Growth.expForLevel(def.growthRate, level, rates)
    local following = level < 100
      and Growth.expForLevel(def.growthRate, level + 1, rates) or current
    local ratio = level >= 100 and 1
      or ((mon.exp or current) - current) / math.max(1, following - current)
    drawXpBar(ratio, panel, meterY + 7, trueColorRegions)
  end

  local function drawTrainerPage(screen, panel, mon, trueColorRegions)
    drawBattleSprite(screen, panel, mon, trueColorRegions, 34, 14)
    drawMediumCentered(monName(screen, mon), panel.x + panel.w / 2,
      panel.y + 51, panel.w - 8, BLACK)
    local player = screen.game.save.player or {}
    drawTinyCentered("OT " .. tostring(mon.ot or player.name or "RED"),
      panel.x + panel.w / 2, panel.y + 67, panel.w - 8, BLACK)
    drawTinyCentered(("ID NO %05d"):format(mon.otId or player.id or 0),
      panel.x + panel.w / 2, panel.y + 78, panel.w - 8, BLACK)
  end

  local function drawStatsPage(screen, panel, mon, trueColorRegions)
    drawBattleSprite(screen, panel, mon, trueColorRegions, 30, 14)
    drawMediumCentered(monName(screen, mon), panel.x + panel.w / 2,
      panel.y + 47, panel.w - 8, BLACK)
    local stats = mon.stats or {}
    local rows = {
      { "ATTACK", stats.attack or 0 }, { "DEFENSE", stats.defense or 0 },
      { "SPEED", stats.speed or 0 }, { "SPECIAL", stats.special or 0 },
    }
    for index, row in ipairs(rows) do
      local y = panel.y + 61 + (index - 1) * 11
      drawTinyText(row[1], panel.x + 5, y, BLACK)
      local value = tostring(row[2])
      drawTinyText(value, panel.x + panel.w - 5 - tinyTextWidth(value), y, BLACK)
    end
  end

  local function drawMovesPage(screen, panel, mon)
    for slot = 1, 4 do
      local move, def = moveInfo(screen, mon, slot)
      local y = panel.y + 15 + (slot - 1) * 23
      if move and def then
        drawMediumCentered(def.name or move.id, panel.x + panel.w / 2,
          y, panel.w - 8, BLACK)
        local detail = typeAbbreviation(def.type) .. " PP ("
          .. tostring(move.pp or 0) .. "/" .. tostring(maxMovePP(move, def))
          .. ")"
        drawTinyCentered(detail, panel.x + panel.w / 2,
          y + 8, panel.w - 8, BLACK)
      else
        drawMediumCentered("NONE", panel.x + panel.w / 2,
          y + 3, panel.w - 8, BLACK)
      end
    end
  end

  local function drawMoveDetailPage(screen, panel, mon, slot)
    local move, def = moveInfo(screen, mon, slot)
    if not (move and def) then
      drawMediumCentered("NONE", panel.x + panel.w / 2,
        panel.y + math.floor((panel.h - 6) / 2), panel.w - 8, BLACK)
      return
    end
    drawMediumCentered(def.name or move.id, panel.x + panel.w / 2,
      panel.y + 7, panel.w - 8, BLACK)
    local accuracy = tonumber(def.accuracy)
    local power = tonumber(def.power)
    local rows = {
      { "TYPE", typeAbbreviation(def.type) },
      { "CLASS", moveClass(def) },
      { "POWER", power and power > 0 and tostring(math.floor(power)) or "---" },
      { "ACCURACY", accuracy and (tostring(math.floor(accuracy)) .. "%") or "---" },
      { "PP", tostring(move.pp or 0) .. "/" .. tostring(maxMovePP(move, def)) },
    }
    for index, row in ipairs(rows) do
      local y = panel.y + 25 + (index - 1) * 15
      drawTinyText(row[1], panel.x + 5, y, BLACK)
      drawTinyText(row[2], panel.x + panel.w - 5 - tinyTextWidth(row[2]),
        y, BLACK)
    end
  end

  local function drawDataPane(screen, panel, mon, location, page,
      trueColorRegions, compact)
    panelFrame(panel, false)
    if not mon then
      drawMediumCentered("EMPTY", panel.x + panel.w / 2,
        panel.y + math.floor((panel.h - 6) / 2), panel.w - 8, BLACK)
      return
    end
    ensurePartyMon(screen, mon)
    if compact then
      drawMonIcon(screen, mon, panel.x + 6, panel.y + 6,
        false, 1, trueColorRegions, detailFaceFor(screen, mon))
      drawMediumText(monName(screen, mon), panel.x + 27, panel.y + 5, BLACK)
      drawTinyText("LVL " .. tostring(mon.level or 1) .. " " .. location,
        panel.x + 27, panel.y + 16, BLACK)
      return
    end
    local def
    if page <= 4 then
      def = drawDataHeader(screen, panel, mon, trueColorRegions)
    else
      def = screen.game.data.pokemon[mon.species] or {}
    end
    if page == 1 then
      drawOverview(screen, panel, mon, location, def, trueColorRegions)
    elseif page == 2 then
      drawTrainerPage(screen, panel, mon, trueColorRegions)
    elseif page == 3 then
      drawStatsPage(screen, panel, mon, trueColorRegions)
    elseif page == 4 then
      drawMovesPage(screen, panel, mon)
    else
      drawMoveDetailPage(screen, panel, mon, page - 4)
    end
  end

  local function detailLocation(screen, heldPane)
    if heldPane then return Strings("MOVING") end
    return screen.region == "party" and Strings("PARTY")
      or Strings("BOX %02d", screen.game.save.currentBox)
  end

  local function drawFooter(screen, layout)
    gray(DARK)
    love.graphics.rectangle("fill", 0, FOOTER_Y, layout.width, 9)
    local message = screen.status
    if not message then
      if screen.held then
        message = Strings("[SELECT] TOGGLE PARTY")
      else
        message = layout.compact and Strings("[A] OPTIONS  [START] DETAILS")
		  or Strings("[A] OPTIONS [START] DETAILS [SELECT] BOXES")
      end
    end
    if screen.boxSwitching then
      message = layout.compact and Strings("ARROWS BOX A DONE")
        or Strings("LEFT RIGHT BOX  A DONE")
    end
	
	local footerX = 4
	local footerW = layout.width - 8
	local textW = Font.width(message)

	local marqueeEnabled = mod and mod.options and mod.options:get("marquee_text") ~= false

	if textW <= footerW or not marqueeEnabled then
	  drawCentered(fitText(message, footerW), layout.width / 2, FOOTER_Y + 1,
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
    panelFrame(layout.box, LIGHT)

    local party = self.game.save.party
    local box = Boxes.active(self.game.save)
    local leftMon, rightMon = paneMons(self)
    if leftPaneShowsDetails(self) and not layout.compact then
      drawDataPane(self, layout.party, leftMon,
        detailLocation(self, false), self.detailPage or 1,
        trueColorRegions, false)
    else
      panelFrame(layout.party, LIGHT)
      for index = 1, Party.MAX do
        drawSlot(self, layout, "party", party, index, trueColorRegions)
      end
    end
    for index = 1, Boxes.CAPACITY do
      drawSlot(self, layout, "box", box, index, trueColorRegions)
    end
    drawDataPane(self, layout.detail, rightMon,
      detailLocation(self, self.held ~= nil), self.detailPage or 1,
      trueColorRegions, layout.compact)
    drawFooter(self, layout)
    drawActions(self, layout)

    local modalCutout
    if self.actions then
      local x, y, width, height = actionGeometry(self, layout)
      modalCutout = { x = x, y = y, w = width + 2, h = height + 2 }
    end
    if not (type(useStockOgMenuPalette) == "function"
        and useStockOgMenuPalette(self.game)) then
      for _, rect in ipairs(trueColorRegions) do
        markTrueColorOutside(rect, modalCutout)
      end
    end
    gray(WHITE)
  end

  function PC:sgbPalettes(game)
    local data = game and game.data
    if not data then return nil end
    local layout = layoutFor(self)
    local selectedMenuPalette = type(menuColors) == "function"
      and menuColors() or nil
    local base = selectedMenuPalette or PaletteFX.pal(data, "BLUEMON")
      or PaletteFX.pal(data, "MEWMON")
    if not base then return nil end
    if type(useStockOgMenuPalette) == "function"
        and useStockOgMenuPalette(game) then
      return {{
        colors = base, x = 0, y = 0, w = layout.width, h = SCREEN_H,
      }}
    end
    local zones = {{
      colors = base, x = 0, y = 0, w = layout.width, h = SCREEN_H,
    }}
    local paper = type(menuPaper) == "function" and menuPaper(game) or nil
    paper = paper or base
    local dataPaper = lockedDataPaper(game) or paper
    zones[#zones + 1] = {
      colors = base, x = 0, y = 0, w = layout.width, h = HEADER_H,
    }
    roundedPaletteFrame(zones, base, base, layout.box, 2)

    local party = self.game.save.party
    local box = Boxes.active(self.game.save)
    local leftMon, detailMon = paneMons(self)
    if leftPaneShowsDetails(self) and not layout.compact then
      local leftBorder = leftMon and ownedTypePalette(self, leftMon) or base
      roundedPaletteFrame(zones, leftBorder, dataPaper, layout.party, 2)
      if leftMon and (self.detailPage or 1) <= 4 then
        local def = self.game.data.pokemon[leftMon.species] or {}
        for _, badge in ipairs(detailTypeBadges(
            layout.party, def.types or {}, genderWidth(leftMon) > 0)) do
          roundedPaletteFrame(zones, badge.palette, dataPaper, badge.rect, 1)
        end
      end
    else
      roundedPaletteFrame(zones, base, base, layout.party, 2)
      for index = 1, Party.MAX do
        local mon = party[index]
        local rect = slotRect(layout, "party", index)
        if mon then
          local border = ownedTypePalette(self, mon)
          roundedPaletteFrame(zones, border, dataPaper, rect, 1)
        else
          local inset = { x = rect.x + 2, y = rect.y + 2,
            w = rect.w - 4, h = rect.h - 4 }
          roundedPaletteFrame(zones, base, dataPaper, inset, 1)
        end
      end
    end
    for index = 1, Boxes.CAPACITY do
      local mon = box[index]
      local rect = slotRect(layout, "box", index)
      if mon then
        local border = ownedTypePalette(self, mon)
        roundedPaletteFrame(zones, border,
          paper, rect, 1)
      else
        local inset = { x = rect.x + 2, y = rect.y + 2,
          w = rect.w - 4, h = rect.h - 4 }
        roundedPaletteFrame(zones, base, paper, inset, 1)
      end
    end
    local detailBorder = detailMon and ownedTypePalette(self, detailMon) or base
    roundedPaletteFrame(zones, detailBorder, dataPaper, layout.detail, 2)
    if detailMon and (self.detailPage or 1) <= 4 then
      local def = self.game.data.pokemon[detailMon.species] or {}
      local hasGender = genderWidth(detailMon) > 0
      for _, badge in ipairs(detailTypeBadges(
          layout.detail, def.types or {}, hasGender)) do
        roundedPaletteFrame(zones, badge.palette, dataPaper, badge.rect, 1)
      end
    end
    zones[#zones + 1] = {
      colors = base, x = 0, y = FOOTER_Y, w = layout.width, h = 9,
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
        selectorBlinkElapsed = 0,
        held = nil,
        boxSwitching = false,
        boxSwitchReturnRegion = nil,
        actions = nil,
        actionIndex = 1,
        status = nil,
        detailPage = 1,
        leftPaneMode = "party",
        leftPaneManual = false,
        modernPCUI = true,
        modernPCLayout = "party-and-box",
        holdsUIAnchors = true,
      }, PC)
    end,
  }
end

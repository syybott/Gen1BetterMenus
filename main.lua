-- Gen1BetterMenus 1.1.1

local Font = require("src.render.Font")
local PaletteFX = require("src.render.PaletteFX")
local Renderer = require("src.render.Renderer")
local Pipelines = require("src.render.Pipelines")
local Zoom = require("src.render.Zoom")
local Game = require("src.core.Game")
local StateStack = require("src.core.StateStack")
local Theme = require("src.ui.Theme")
local Strings = require("src.core.Strings")

local OptionRows = require("src.ui.OptionRows")
local Screens = require("src.ui.Screens")
local OptionsMenu = require("src.ui.OptionsMenu")
local PaletteScreen = require("src.ui.PaletteScreen")
local ListMenu = require("src.ui.ListMenu")
local Menu = require("src.ui.Menu")
local BoxMenu = require("src.ui.BoxMenu")
local BagMenu = require("src.ui.BagMenu")
local PlayerPC = require("src.ui.PlayerPC")
local PokedexMenu = require("src.ui.PokedexMenu")
local PartyMenu = require("src.ui.PartyMenu")
local TrainerCard = require("src.ui.TrainerCard")
local DexEntryMenu = require("src.ui.DexEntryMenu")
local NamingScreen = require("src.ui.NamingScreen")
local SummaryMenu = require("src.ui.SummaryMenu")
local TextBox = require("src.render.TextBox")
local ChoiceBox = require("src.ui.ChoiceBox")
local QuantityBox = require("src.ui.QuantityBox")
local ManagerState = require("src.mods.ManagerState")
local LinkState = require("src.link.LinkState")
local BattleState = require("src.battle.BattleState")
local QuarantineReport = require("src.ui.QuarantineReport")
local TitleState = require("src.ui.TitleState")
local OakSpeech = require("src.ui.OakSpeech")
local OverworldState = require("src.world.OverworldController")
local Runtime = require("src.mods.Runtime")
local Bag = require("src.inventory.Bag")

local UI_W, UI_H = 304, 144
local UI_TW, UI_TH = UI_W / 8, UI_H / 8
local TITLE_PANEL_TW = 13
local TITLE_INFO_TH = 10

-- The stock vertical border glyph sits one pixel left of the corner stems.
-- Repaint only the repeated left edge one game pixel to the right; corners
-- and the other three edges retain the engine's original placement.
if not Font.gen1BetterMenusLeftBorderFix then
  local originalDrawBox = Font.drawBox
  local function usesStockBorder()
    for key, code in pairs(Font.DEFAULT_BORDER or {}) do
      if Font.BORDER[key] ~= code then return false end
    end
    return true
  end

  Font.drawBox = function(tx, ty, tw, th, fill)
    originalDrawBox(tx, ty, tw, th, fill)
    if th <= 2 or not usesStockBorder() then return end

    local r, g, b, a = love.graphics.getColor()
    if type(fill) == "table" and fill[1] and fill[2] and fill[3] then
      love.graphics.setColor(fill[1] / 255, fill[2] / 255,
        fill[3] / 255, 1)
    else
      love.graphics.setColor(1, 1, 1, 1)
    end
    love.graphics.rectangle("fill", tx * 8, (ty + 1) * 8,
      8, (th - 2) * 8)
    love.graphics.setColor(r, g, b, a)

    for j = 1, th - 2 do
      Font.drawCode(Font.BORDER.v, tx * 8 + 1, (ty + j) * 8)
    end
  end
  Font.gen1BetterMenusLeftBorderFix = true
end

local function centeredTitlePanel(th)
  return math.floor((UI_TW - TITLE_PANEL_TW) / 2),
    math.floor((UI_TH - th) / 2)
end

local PALETTES = {
  gameboy = PaletteFX.CLASSIC,
  blackwhite = PaletteFX.GRAYS,
  ogred = PaletteFX.GBC_BG,
  ogredobj = PaletteFX.GBC_OBJ,
  ogblue = PaletteFX.GBC_BG_BLUE,
  classic = PaletteFX.CLASSIC,
  og = PaletteFX.GRAYS,
  redpp = PaletteFX.GBC_OBJ,
  gbc = PaletteFX.GBC_BG_BLUE,

  soulsilver = {
    { 248, 248, 248 }, { 168, 208, 232 },
    { 72, 128, 168 }, { 16, 40, 72 },
  },
  heartgold = {
    { 255, 248, 224 }, { 232, 200, 120 },
    { 168, 112, 48 }, { 64, 40, 24 },
  },
  firered = {
    { 255, 248, 232 }, { 240, 168, 144 },
    { 184, 72, 64 }, { 72, 24, 32 },
  },
  leafgreen = {
    { 248, 255, 232 }, { 168, 224, 152 },
    { 72, 152, 88 }, { 24, 56, 40 },
  },
  crystal = {
    { 248, 248, 255 }, { 176, 224, 240 },
    { 80, 144, 200 }, { 24, 48, 88 },
  },
  emerald = {
    { 248, 255, 240 }, { 160, 224, 184 },
    { 48, 152, 112 }, { 16, 56, 48 },
  },
  amiga_wb = {
	{ 210, 210, 210 }, { 255, 136, 0 },
	{ 0, 85, 170 }, { 0, 0, 0 },
  },
  amiga_dp = {
	{ 221, 221, 238 }, { 119, 136, 187 },
	{ 68, 68, 119 }, { 17, 17, 34 },
  },
  c64 = {
	{ 160, 160, 255 }, { 108, 94, 181 },
	{ 64, 49, 141 }, { 24, 16, 72 },
  },
  spectrum = {
	{ 255, 255, 255 }, { 0, 204, 204 },
	{ 204, 0, 204 }, { 0, 0, 0 },
  },
  cga = {
	{ 255, 255, 255 }, { 60, 230, 230 },
	{ 255, 85, 255 }, { 0, 0, 0 },
  },
  apple2 = {
	{ 200, 255, 200 }, { 80, 220, 110 },
	{ 30, 130, 60 }, { 8, 32, 16 },
  },
  pocket = {
	{ 224, 224, 224 }, { 160, 160, 160 },
	{ 88, 88, 88 }, { 24, 24, 24 },
  },
  gblight = {
	{ 0, 251, 199 }, { 0, 187, 155 },
	{ 0, 107, 96 }, { 0, 48, 48 },
  },
  virtualboy = {
	{ 255, 150, 130 }, { 215, 45, 32 },
	{ 120, 12, 8 }, { 12, 0, 0 },
  },
  amber = {
	{ 255, 196, 64 }, { 200, 140, 30 },
	{ 120, 76, 10 }, { 24, 12, 0 },
  },
  phosphor = {
	{ 170, 255, 170 }, { 80, 200, 90 },
	{ 30, 110, 45 }, { 5, 25, 10 },
  },
  plasma = {
	{ 255, 230, 180 }, { 255, 140, 60 },
	{ 170, 40, 90 }, { 30, 10, 40 },
  },
  rainbow = {
	{ 255, 241, 120 }, { 255, 120, 150 },
	{ 150, 70, 200 }, { 30, 20, 80 },
  },
  acid = {
	{ 236, 255, 150 }, { 120, 225, 140 },
	{ 150, 60, 190 }, { 35, 15, 55 },
  },
  fuchsia = {
	{ 255, 214, 240 }, { 255, 105, 190 },
	{ 170, 30, 120 }, { 40, 0, 40 },
  },
  sunset = {
	{ 255, 224, 168 }, { 255, 140, 90 },
	{ 170, 60, 90 }, { 40, 20, 60 },
  },
  ocean = {
	{ 200, 245, 255 }, { 80, 190, 220 },
	{ 25, 95, 150 }, { 5, 20, 60 },
  },
  forest = {
	{ 214, 240, 180 }, { 130, 190, 90 },
	{ 50, 110, 60 }, { 12, 35, 25 },
  },
  lava = {
	{ 255, 240, 180 }, { 255, 150, 40 },
	{ 180, 40, 20 }, { 35, 8, 8 },
  },
  ice = {
	{ 240, 252, 255 }, { 170, 220, 245 },
	{ 80, 130, 190 }, { 20, 35, 80 },
  },
  candy = {
	{ 255, 235, 245 }, { 255, 160, 200 },
	{ 190, 90, 160 }, { 60, 25, 70 },
  },
  vapor = {
	{ 245, 225, 255 }, { 95, 185, 205 },
	{ 200, 80, 180 }, { 45, 20, 70 },
  },
  neon = {
	{ 225, 255, 90 }, { 60, 230, 180 },
	{ 200, 40, 160 }, { 15, 10, 35 },
  },
  toxic = {
	{ 225, 255, 60 }, { 130, 210, 30 },
	{60, 120, 25}, {15, 30, 10},
  },
  sepia = {
	{ 240, 224, 196 }, { 186, 155, 116 },
	{ 110, 84, 58 }, { 32, 24, 18 },
  },
  noir = {
	{ 245, 245, 245 }, { 150, 150, 155 },
	{ 60, 60, 68 }, { 0, 0, 0 },
  },
  cherry = {
	{ 255, 225, 225 }, { 235, 90, 90 },
	{ 150, 25, 45 }, { 40, 5, 15 },
  },
  midnight = {
	{ 180, 195, 235 }, { 90, 110, 180 },
	{ 40, 50, 110 }, { 8, 10, 30 },
  },
  gold = {
	{ 255, 244, 200 }, { 228, 190, 80 },
	{ 150, 110, 30 }, { 40, 28, 8 },
  },
  mint = {
	{ 224, 255, 240 }, { 130, 225, 190 },
	{ 45, 140, 120 }, { 10, 45, 40 },
  },
  grape = {
	{ 235, 220, 255 }, { 170, 130, 225 },
	{ 95, 55, 150 }, { 28, 12, 50 },
  },
}

local PAPER_COLORS = {
  soulsilver  = { 238, 244, 248 },
  heartgold   = { 248, 242, 224 },
  firered     = { 250, 238, 234 },
  leafgreen   = { 241, 247, 235 },
  crystal     = { 240, 246, 250 },
  emerald     = { 239, 247, 241 },

  amiga_wb    = { 238, 234, 226 },
  amiga_dp    = { 235, 235, 244 },
  c64         = { 232, 230, 246 },
  spectrum    = { 240, 240, 240 },
  cga         = { 242, 242, 242 },
  apple2      = { 235, 246, 236 },
  pocket      = { 236, 236, 236 },
  gblight     = { 224, 242, 237 },
  virtualboy  = { 248, 232, 228 },
  amber       = { 247, 239, 220 },
  phosphor    = { 234, 246, 234 },

  plasma      = { 248, 238, 224 },
  rainbow     = { 247, 241, 224 },
  acid        = { 242, 246, 226 },
  fuchsia     = { 247, 235, 243 },
  sunset      = { 248, 237, 226 },
  ocean       = { 232, 244, 247 },
  forest      = { 237, 244, 230 },
  lava        = { 248, 240, 222 },
  ice         = { 239, 247, 249 },
  candy       = { 248, 238, 243 },
  vapor       = { 243, 237, 247 },
  neon        = { 239, 244, 226 },
  toxic       = { 240, 244, 225 },
  sepia       = { 241, 233, 219 },
  noir        = { 238, 238, 240 },
  cherry      = { 248, 236, 236 },
  midnight    = { 232, 235, 244 },
  gold        = { 246, 239, 220 },
  mint        = { 236, 247, 242 },
  grape       = { 240, 235, 247 },
}

-- Yellow's CGB title colors.  The normal SGB title palettes deliberately use
-- softer yellow, lavender, and pink shades; the Yellow title art instead uses
-- the vivid CGBBasePalettes colors seen on the intended full-color title.
local YELLOW_TITLE_LOGO = {
  { 255, 255, 255 }, { 255, 255, 0 },
  { 58, 58, 206 }, { 0, 0, 140 },
}
local YELLOW_TITLE_PIKACHU = {
  { 255, 255, 255 }, { 255, 255, 0 },
  { 255, 8, 8 }, { 25, 25, 25 },
}

local activeMod
local activeGame

local function modernBattleUIMode()
  if not activeMod then return "on" end
  local ok, value = pcall(activeMod.options.get, activeMod.options,
    "modern_battle_ui")
  if not ok or value == nil or value == true then return "on" end
  if value == false then return "off" end
  return value == "mod" and "mod" or value == "off" and "off" or "on"
end

local function modernBattleUIEnabled()
  return modernBattleUIMode() == "on"
end
local LOCATION_OVERLAY_KEY = "__qolLocationBannerOverlay"
local locationStates = setmetatable({}, { __mode = "k" })
local locationOverlays = setmetatable({}, { __mode = "k" })

-- PaletteFX normally applies the engine's active display mode after a state
-- supplies its zones. Under BetterMenus ownership, BetterMenus-owned menu
-- palettes bypass that final substitution and reach the shader directly.
PaletteFX.gen1BetterMenusRawZonePalettes =
  PaletteFX.gen1BetterMenusRawZonePalettes
  or setmetatable({}, { __mode = "k" })

local function isBetterMenusPalette(palette)
  if type(palette) ~= "table" then return false end
  return palette.gen1BetterMenusOwned == true
    or PaletteFX.gen1BetterMenusRawZonePalettes[palette] == true
end

local function rawMenuPaletteCopy(source)
  if type(source) ~= "table" then return source end
  local clone = {
    source[1] and { source[1][1], source[1][2], source[1][3] } or { 255, 255, 255 },
    source[2] and { source[2][1], source[2][2], source[2][3] } or { 170, 170, 170 },
    source[3] and { source[3][1], source[3][2], source[3][3] } or { 85, 85, 85 },
    source[4] and { source[4][1], source[4][2], source[4][3] } or { 0, 0, 0 },
  }
  clone.gen1BetterMenusOwned = true
  PaletteFX.gen1BetterMenusRawZonePalettes[clone] = true
  return clone
end

if not PaletteFX.gen1BetterMenusRawZoneHookInstalled then
  local originalSendColors = PaletteFX.sendColors
  local originalEffectiveColors = PaletteFX.effectiveColors
  PaletteFX.sendColors = function(shader, palette)
    if isBetterMenusPalette(palette) then
      shader:send("c0", { palette[1][1] / 255,
        palette[1][2] / 255, palette[1][3] / 255 })
      shader:send("c1", { palette[2][1] / 255,
        palette[2][2] / 255, palette[2][3] / 255 })
      shader:send("c2", { palette[3][1] / 255,
        palette[3][2] / 255, palette[3][3] / 255 })
      shader:send("c3", { palette[4][1] / 255,
        palette[4][2] / 255, palette[4][3] / 255 })
      return
    end
    return originalSendColors(shader, palette)
  end
  PaletteFX.effectiveColors = function(palette, ...)
    if isBetterMenusPalette(palette) then
      return palette
    end
    return originalEffectiveColors(palette, ...)
  end
  PaletteFX.gen1BetterMenusRawZoneHookInstalled = true
end

local function useStockOgMenuPalette(game)
  return false
end

local function bypassOgTransformForZones(zones)
  for _, zone in ipairs(zones or {}) do
    local source = zone and zone.colors
    if type(source) == "table" and not isBetterMenusPalette(source) then
      zone.colors = rawMenuPaletteCopy(source)
    end
  end
  return zones
end

-- Rendering contract:
-- 1. When a BetterMenus menu palette is enabled, BetterMenus owns the palette used to render BetterMenus menu UI.
-- 2. Upstream may continue to own overworld/game palettes and any screens BetterMenus does not override.
-- 3. Global upstream palette settings such as inverse must not silently replace or reorder BetterMenus menu palette ownership.
-- 4. Menu geometry is identical in NORMAL and INVERSE.
-- 5. colors() always returns canonical palette order.
-- 6. INVERSE is applied once by effectiveMenuPalette().
-- 7. Semantic HP/XP colors are excluded from menu-palette remapping unless an OG engine palette is active.
-- 8. Renderers must never reverse or un-reverse palettes themselves.

local function colors(game)
  local id = activeMod and activeMod.options:get("palette") or "soulsilver"
  local palette = PALETTES[id] or PALETTES.soulsilver
  return rawMenuPaletteCopy(palette)
end

local function effectiveMenuPalette(game)
  local palette = colors(game)
  if not (activeMod and activeMod.options:get("inverse")) then
    return palette
  end
  local inverse = {
    palette[4], palette[3], palette[2], palette[1],
  }
  return rawMenuPaletteCopy(inverse)
end

local function effectivePaperPalette(game)
  local palette = effectiveMenuPalette(game)
  local id = activeMod and activeMod.options:get("palette") or "soulsilver"
  local paper = PAPER_COLORS[id]
  if type(palette) ~= "table" or type(paper) ~= "table" then return nil end
  local surface = {
    paper, palette[2], palette[3], palette[4],
  }
  return rawMenuPaletteCopy(surface)
end

local function wholeWide()
  return { PaletteFX.zone(effectiveMenuPalette(), 0, 0, UI_TW - 1, UI_TH - 1) }
end

local function makeWideState(class)
  class.uiSize = function() return UI_W, UI_H end
  -- Only inherit the wide-battle marker when a battle actually owns the
  -- stack. Claiming it over the overworld makes Game.lua apply the battle's
  -- 72px classic-content offset to the map beneath the menu.
  class.isWideBattleLayout = function(self)
    local states = self.game and self.game.stack and self.game.stack.states
      or {}
	    -- An opaque child completely replaces this screen.
  -- Do not let this wide menu masquerade as a wide battle underneath it,
  -- or Game.drawBaseInStack will deliberately draw through the opaque child.
  local selfIndex
  for i = 1, #states do
    if states[i] == self then
      selfIndex = i
      break
    end
  end

  if selfIndex then
    for i = selfIndex + 1, #states do
      if states[i] and states[i].isOpaque then
        return false
      end
    end
  end

	local hasBattle = false
	for i = 1, #states do
	  if states[i] ~= self and states[i] and states[i].isBattle then
	    hasBattle = true
	    break
	  end
	end
	if not hasBattle then return false end

	  local base = self.game.stack:visibleBase()
	  local baseState = states[base]
      if baseState and baseState.isOverworld then
	    return true
end	
    for i = 1, #states do
      if states[i] ~= self and states[i] and (states[i].isBattle or not states[i].isOverworld) then
        return true
      end
    end
    return false
  end
  -- These menus are panels over the field. Keeping them non-opaque lets the
  -- normal world pass replace the black letterbox around the wide panel.
  class.isOpaque = false
end

local function isOptionRowsScreen(state)
  if not state or not state.rows then return false end

  -- New Gen1Recomp opt-in marker for mod-created options screens.
  if state.isModOptions then return true end

  -- Legacy fallback for older builds/mods that do not declare isModOptions.
  local sid = type(state.screenId) == "string"
    and state.screenId
    or ""

  return sid:match("Options$")
      or sid:match("Settings$")
end

local function installModOptionsMarkerCompatibility()
  local function propagate(game, id, inst)
    if not inst or inst.isModOptions ~= nil then
      return inst
    end

    local factory = Screens.get(game, id)
    if factory and factory.isModOptions then
      inst.isModOptions = true
    end

    return inst
  end

  local originalBuild = Screens.build
  Screens.build = function(game, id, ...)
    return propagate(game, id, originalBuild(game, id, ...))
  end

  local originalPush = Screens.push
  Screens.push = function(game, id, ...)
    return propagate(game, id, originalPush(game, id, ...))
  end
end

local function installOverworldScaleStability()
  local originalDraw = Game.draw
  local originalUiScale = Renderer.uiScale
  local originalOffsetRange = Zoom.offsetRange

  local function fitFor(w, h)
    local oldW, oldH = Renderer.uiWidth, Renderer.uiHeight
    Renderer.uiWidth, Renderer.uiHeight = w, h
    local scale = Renderer:fitScale()
    Renderer.uiWidth, Renderer.uiHeight = oldW, oldH
    return scale
  end

  Game.draw = function(self)
    local states = self.stack and self.stack.states or {}
    local top = self.stack and self.stack:top()
	local below = states[#states - 1]
	if top and getmetatable(top) == Menu
	    and below and below.gen1BetterMenusBagFavorites
	    and not below.modernBagUI then
	  top.gen1BetterMenusBagSubmenu = true
	  top.uiSize = function() return below:uiSize() end
	  top.sgbPalettes = below.sgbPalettes
	end
	local sid = top and type(top.screenId) == "string"
  and top.screenId:lower() or ""

	local dynamicOptionRows =
	  top
	  and type(top.rows) == "function"
	  and type(top.index) == "number"
	  and type(top.scroll) == "number"

	if isOptionRowsScreen(top)
		or (dynamicOptionRows
		  and not top.gen1BetterMenusBagFavorites
		  and not top.gen1BetterMenusBagSubmenu) then
	  top.uiSize = function() return UI_W, UI_H end
	  top.isWideBattleLayout = function() return false end
	end

    local worldBelow, battlePresent = false, false
    for i = 1, #states do
      if states[i] == self.overworld then worldBelow = true end
      if states[i] and states[i].isBattle then battlePresent = true end
    end

    local wideW, wideH
    if top and top ~= self.overworld and top.uiSize then
      wideW, wideH = top:uiSize()
    end
    local stabilize = worldBelow and not battlePresent
      and wideW and wideH and wideW > Renderer.WIDTH
    if not stabilize then return originalDraw(self) end

    local classicScale = fitFor(Renderer.WIDTH, Renderer.HEIGHT)
    local wideScale = fitFor(wideW, wideH)
    local savedOffset = Zoom.offset
    local desiredScale = Zoom.scale(classicScale)
    local classicLo, classicHi = originalOffsetRange(classicScale)

    -- Wide overlays reduce fitScale because their canvas is 304px across.
    -- Translate the saved survey-zoom offset for this draw only so the world
    -- retains exactly the scale it had before the overlay opened. UI keeps
    -- using the player's unmodified offset and its own wide fit scale.
    Zoom.offset = desiredScale - wideScale
    Zoom.offsetRange = function(scale)
      if scale == wideScale then
        return classicScale + classicLo - wideScale,
               classicScale + classicHi - wideScale
      end
      return originalOffsetRange(scale)
    end
    Renderer.uiScale = function(renderer)
      local adjusted = Zoom.offset
      Zoom.offset = savedOffset
      local scale = originalUiScale(renderer)
      Zoom.offset = adjusted
      return scale
    end

    local ok, err = pcall(originalDraw, self)
    Renderer.uiScale = originalUiScale
    Zoom.offsetRange = originalOffsetRange
    Zoom.offset = savedOffset
    if not ok then error(err) end
  end
end

local function rowText(row, game)
  if not row then return "" end
  local value = row.value and row.value(game) or ""
  return Strings(value)
end

local function drawOuterFrame(title)
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.rectangle("fill", 0, 0, UI_W, UI_H)
  Font.drawBox(0, 0, UI_TW, UI_TH)
  love.graphics.setColor(0, 0, 0, 1)
  if title then Font.draw(Strings(title), 16, 8) end
end

local function pcOverlayAbove(menu)
  local states = menu.game and menu.game.stack and menu.game.stack.states or {}
  for i = 1, #states do
    if states[i] == menu then
      for j = i + 1, #states do
        local above = states[j]
        local aboveMt = getmetatable(above)
        if aboveMt == Menu or aboveMt == ListMenu or above.isTextBox then
          return true
        end
      end
      break
    end
  end
  return false
end

local function drawPCChrome(game)
  Font.drawBox(0, 12, UI_TW, 6)
  love.graphics.setColor(0, 0, 0, 1)
  Font.draw(Strings("What?"), 8, 112)
  Font.drawBox(UI_TW - 11, 14, 11, 4)
  love.graphics.setColor(0, 0, 0, 1)
  Font.draw(Strings("BOX No."), (UI_TW - 10) * 8, 128)
  local n = game.save.currentBox or 1
  Font.draw(tostring(n), (n >= 10 and UI_TW - 3 or UI_TW - 2) * 8, 128)
  love.graphics.setColor(1, 1, 1, 1)
end

local function isCenterPCMenu(items, opts)
  if not opts.noSound or #items < 3 then return false end
  local first = tostring(items[1] and items[1].label or "")
  local second = tostring(items[2] and items[2].label or "")
  local last = tostring(items[#items] and items[#items].label or "")
  return (first == "BILL'S PC" or first == "SOMEONE'S PC")
    and second:match("'s PC$") ~= nil
    and last == "LOG OFF"
end

local function installReportLayout()
  QuarantineReport.uiSize = function()
    return UI_W, UI_H
  end

  QuarantineReport.isWideBattleLayout = function()
    return false
  end

  QuarantineReport.isOpaque = false

  QuarantineReport.sgbPalettes = function()
    return { PaletteFX.zone(effectiveMenuPalette(), 0, 0, UI_TW - 1, UI_TH - 1) }
  end

  local originalReportDraw = QuarantineReport.draw

  QuarantineReport.draw = function(self)
    love.graphics.setColor(1, 1, 1, 1)

    love.graphics.push()
    love.graphics.translate(72, 0)
    originalReportDraw(self)
    love.graphics.pop()
  end
end

local function drawFrameOnly(tx, ty, tw, th)
  local B = Font.BORDER
  Font.drawCode(B.tl, tx * 8, ty * 8)
  Font.drawCode(B.tr, (tx + tw - 1) * 8, ty * 8)
  Font.drawCode(B.bl, tx * 8, (ty + th - 1) * 8)
  Font.drawCode(B.br, (tx + tw - 1) * 8, (ty + th - 1) * 8)
  for i = 1, tw - 2 do
    Font.drawCode(B.h, (tx + i) * 8, ty * 8)
    Font.drawCode(B.h, (tx + i) * 8, (ty + th - 1) * 8)
  end
  for j = 1, th - 2 do
    Font.drawCode(B.v, tx * 8 + 1, (ty + j) * 8)
    Font.drawCode(B.v, (tx + tw - 1) * 8, (ty + j) * 8)
  end
end

local function truncate(text, cols)
  local spans = Font.split(tostring(text or ""))
  if #spans <= cols then return tostring(text or "") end
  return tostring(text or ""):sub(1, spans[cols].to)
end

local function wrapText(text, cols)
  local lines = {}
  for paragraph in tostring(text or ""):gmatch("[^\n]+") do
    local line = ""
    for word in paragraph:gmatch("%S+") do
      local candidate = line == "" and word or line .. " " .. word
      if Font.width(candidate) > cols * 8 and line ~= "" then
        lines[#lines + 1] = truncate(line, cols)
        line = word
      else
        line = candidate
      end
    end
    lines[#lines + 1] = truncate(line, cols)
  end
  if #lines == 0 then lines[1] = "" end
  return lines
end

local function installOptionsLayout()
  OptionRows.VISIBLE = 12

local originalScreensBuild = Screens.build

Screens.push = function(game, id, ...)
  local inst = originalScreensBuild(game, id, ...)

if isOptionRowsScreen(inst) then
    inst.uiSize = function()
      return UI_W, UI_H
    end
    inst.isWideBattleLayout = function()
      return false
    end
	
	inst.sgbPalettes = wholeWide
  end

  game.stack:push(inst)
  return inst
end
  OptionRows.draw = function(game, rows, index, scroll, bottomLabel, bottomRow)
    drawOuterFrame("OPTIONS")
    for slot = 1, OptionRows.VISIBLE do
      local i = scroll + slot
      local row = rows[i]
      if not row then break end
      local y = 16 + slot * 8
      Font.draw(Strings(row.label), 24, y)
      local value = rowText(row, game)
      Font.draw(value, UI_W - 16 - Font.width(value), y)
      if i == index then Font.drawCode(Theme.cursor, 16, y) end
    end
    if scroll + OptionRows.VISIBLE < #rows then
      Font.drawCode(Theme.moreArrow, UI_W - 24, 120)
    end
    if bottomLabel then
      Font.draw(Strings(bottomLabel), 24, 128)
      if bottomRow and index == bottomRow then
        Font.drawCode(Theme.cursor, 16, 128)
      end
    end
    love.graphics.setColor(1, 1, 1, 1)
  end

  makeWideState(OptionsMenu)
  local originalOptionsWide = OptionsMenu.isWideBattleLayout

OptionsMenu.isWideBattleLayout = function(self)
  local states = self.game and self.game.stack and self.game.stack.states or {}

  for i = 1, #states - 1 do
    if states[i] == self then
      local child = states[i + 1]

	if isOptionRowsScreen(child) then
	  return false
	end

      break
    end
  end

  return originalOptionsWide(self)
end
  OptionsMenu.sgbPalettes = wholeWide
  -- ManagerState uses OptionRows for each mod's settings page. Without the
  -- same canvas declaration the compact 38-tile renderer would be clipped
  -- back to the manager's original 20-tile surface.
  makeWideState(ManagerState)
  ManagerState.sgbPalettes = wholeWide
end

local function installListLayout()
  makeWideState(ListMenu)
  ListMenu.uiSize = function(self)
    if self.gen1BetterMenusBagFavorites then
      return 304, 168
    end

    return UI_W, UI_H
  end
  QuantityBox.uiSize = function() return UI_W, UI_H end
  QuantityBox.isWideBattleLayout = function() return false end
  local originalListMenuNew = ListMenu.new
  local originalListMenuUpdate = ListMenu.update

  local function favoriteItems(save)
    save.gen1BetterMenusFavoriteItems =
      save.gen1BetterMenusFavoriteItems or {}
    return save.gen1BetterMenusFavoriteItems
  end

  local function sortBagFavorites(list)
    if not list.gen1BetterMenusBagFavorites then return end
    for i = #list.items, 1, -1 do
      if list.items[i].cancel then table.remove(list.items, i) end
    end
    local selected = list.items[list.index]
    local selectedId = selected and selected.value
    local rank = {}
    for i, id in ipairs(Bag.order(list.game.save)) do rank[id] = i end
    local favorites = favoriteItems(list.game.save)
    table.sort(list.items, function(a, b)
      local af, bf = favorites[a.value] == true, favorites[b.value] == true
      if af ~= bf then return af end
      return (rank[a.value] or math.huge) < (rank[b.value] or math.huge)
    end)
    if selectedId then
      for i, item in ipairs(list.items) do
        if item.value == selectedId then list.index = i break end
      end
    end
    local maxRow = list.cursorRows or list.rows
    if list.index - list.scroll > maxRow then
      list.scroll = list.index - maxRow
    elseif list.index - list.scroll < 1 then
      list.scroll = list.index - 1
    end
  end

  local function drawFavoriteHeart(x, y)
    love.graphics.rectangle("fill", x + 1, y + 1, 2, 1)
    love.graphics.rectangle("fill", x + 4, y + 1, 2, 1)
    love.graphics.rectangle("fill", x, y + 2, 7, 2)
    love.graphics.rectangle("fill", x + 1, y + 4, 5, 1)
    love.graphics.rectangle("fill", x + 2, y + 5, 3, 1)
    love.graphics.rectangle("fill", x + 3, y + 6, 1, 1)
  end

ListMenu.new = function(game, ...)
  local self = originalListMenuNew(game, ...)
  local bagItems = self.itemBox and self.kind == "bag"

  -- Newer Gen1Recomp builds mark the overworld bag as a partial item box,
  -- which disables its palette and leaves the wide replacement transparent.
  -- This mod owns the bag's full-screen layout, so restore only that instance.
  if self.itemBox then
    self.itemBox = false
    self.isOpaque = false
    self.sgbPalettes = wholeWide
    self.rows = 7
    self.cursorRows = nil
  end

  if bagItems then
    self.gen1BetterMenusBagFavorites = true

    self.sgbPalettes = function()
      return {
        PaletteFX.zone(effectiveMenuPalette(), 0, 0, 37, 20)
      }
    end

    self.rows = 8

    self.update = function(list, dt)
      if list.game.input:wasPressed("up") and list.index == 1 then
        list.index = #list.items
        local maxRow = list.cursorRows or list.rows
        list.scroll = math.max(0, #list.items - maxRow)
        list.holdDir, list.holdFrames = "up", 0
        return
      end
      if list.game.input:wasPressed("down")
          and list.index == #list.items then
        list.index = 1
        list.scroll = 0
        list.holdDir, list.holdFrames = "down", 0
        return
      end
      if list.game.input:wasPressed("start") then
        local item = list.items[list.index]
        if not item then return end
        local favorites = favoriteItems(game.save)
        favorites[item.value] = not favorites[item.value] or nil
        require("src.core.Sound").play(game.data, "Swap")
        sortBagFavorites(list)
        return
      end
      originalListMenuUpdate(list, dt)
    end

    sortBagFavorites(self)
  end

  local parent = game and game.stack and game.stack:top()
  if parent and getmetatable(parent) == Menu then
  self.isWideBattleLayout = function() return false end
  end

  return self
end
  ListMenu.sgbPalettes = wholeWide
  -- PokedexMenu stamps its own palette function onto the ListMenu instance,
  -- so update that factory-owned function as well as the generic class.
  PokedexMenu.sgbPalettes = wholeWide

  -- Current Gen1Recomp gives the Pokédex contents screen its own renderer
  -- rather than a ListMenu instance. Lay that renderer out across the wide
  -- surface instead of leaving its native 160px contents at the left edge.
  PokedexMenu.isOpaque = false
  PokedexMenu.uiSize = function() return UI_W, UI_H end
  PokedexMenu.isWideBattleLayout = function() return false end
  PokedexMenu.draw = function(self)
    local dividerTx, sideX = 24, 208
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("fill", 0, 0, UI_W, UI_H)

    local dividerX = dividerTx * 8 + 3
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.rectangle("fill", dividerX, 8, 2, UI_H - 16)
    for ty = 2, 16, 2 do
      local nodeY = ty * 8
      love.graphics.rectangle("fill", dividerX - 2, nodeY - 3, 6, 6)
      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.rectangle("fill", dividerX - 1, nodeY - 2, 4, 4)
      love.graphics.setColor(0, 0, 0, 1)
    end

    local at = self.rowsAt
    love.graphics.setColor(0, 0, 0, 1)
    Font.draw(("─"):rep(12), sideX - 8, at.rule * 8)
    Font.draw(Strings("CONTENTS"), 8, 8)
    Font.draw(Strings("SEEN"), sideX, at.seen * 8)
    Font.draw(Strings("OWN"), sideX, at.own * 8)

    local function count(n, ty)
      local text = tostring(n)
      Font.draw(text, UI_W - 8 - Font.width(text), ty * 8)
    end
    count(self.seenCount, at.seen)
    count(self.ownedCount, at.own)

    for i, label in ipairs(self:sideItems()) do
      Font.draw(label, sideX, (at.items + (i - 1) * 2) * 8)
    end

    for row = 1, self:rows() do
      local index = self.scroll + row
      local item = self.items[index]
      if not item then break end
      local rowY = 24 + (row - 1) * 16
      if item.ball then
        love.graphics.circle("fill", 28, rowY + 4, 3.5)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.rectangle("fill", 24.5, rowY + 3.5, 7, 1)
        love.graphics.circle("fill", 28, rowY + 4, 1.2)
        love.graphics.setColor(0, 0, 0, 1)
      end
      Font.draw(item.name, 40, rowY)
      local numX = dividerTx * 8 - 16 - Font.width(item.num)
      love.graphics.rectangle("fill", numX + 2, rowY + 1, 1, 6)
      love.graphics.rectangle("fill", numX + 5, rowY + 1, 1, 6)
      love.graphics.rectangle("fill", numX + 1, rowY + 3, 6, 1)
      love.graphics.rectangle("fill", numX + 1, rowY + 5, 6, 1)
      Font.draw(item.num, numX + 8, rowY)
      if index == self.index then
        Font.drawCode(self.hollowIndex == index
          and Theme.cursorHollow or Theme.cursor, 8, rowY)
      end
    end
    drawFrameOnly(0, 0, UI_TW, UI_TH)
    love.graphics.setColor(1, 1, 1, 1)
  end

  local originalDexChoose = PokedexMenu.onChoose
  PokedexMenu.onChoose = function(item, dexList)
    originalDexChoose(item, dexList)
    local top = dexList.game.stack:top()
    if top and getmetatable(top) == Menu then
      top.tx = 24
    end
  end

  ListMenu.draw = function(self)
    local states = self.game and self.game.stack and self.game.stack.states or {}

    for i = 1, #states - 1 do
      if states[i] == self
          and getmetatable(states[i + 1]) == DexEntryMenu then
        return
      end
    end
    sortBagFavorites(self)
    if self.gen1BetterMenusBagFavorites then
      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.rectangle("fill", 0, 0, 304, 168)
      drawFrameOnly(0, 0, 38, 21)
      love.graphics.setColor(0, 0, 0, 1)

      if self.title then
        Font.draw(Strings(self.title), 16, 8)
      end
    else
      drawOuterFrame(self.title)
    end
    if #self.items == 0 then
      Font.draw(Strings("Nothing here."), 24, 64)
    end
    for row = 1, self.rows do
      local i = self.scroll + row
      local item = self.items[i]
      if not item then break end
      local y = 8 + row * 16
      local labelX = 24
      if self.gen1BetterMenusBagFavorites
          and i ~= self.index
          and self.swapIndex ~= i
          and favoriteItems(self.game.save)[item.value] then
        drawFavoriteHeart(16, y)
      end
      Font.draw(item.label, labelX, y)
      if item.ball then
        local bx, by = labelX + Font.width(item.label) + 11, y + 3
        love.graphics.circle("fill", bx, by, 3.5)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.rectangle("fill", bx - 3.5, by - 0.5, 7, 1)
        love.graphics.circle("fill", bx, by, 1.2)
        love.graphics.setColor(0, 0, 0, 1)
      end
      if item.right then
        Font.draw(item.right, UI_W - 16 - Font.width(item.right), y)
      end
      if i == self.index then
        Font.drawCode(self.hollowIndex == i and Theme.cursorHollow
                      or Theme.cursor, 16, y)
      end
      if self.swapIndex == i and i ~= self.index then
        Font.drawCode(Theme.cursorHollow, 16, y)
      end
    end

    if self.dialogue then
      Font.drawBox(27, 0, 11, 3)
      local money = ("¥%d"):format(self.money and self.money() or 0)
      Font.draw(money, UI_W - 8 - Font.width(money), 8)
    end

    if self.dialogue or (self.messageBox and self.footer) then
      Font.drawBox(0, 13, UI_TW, 5)
      if self.footer then
        local flat = {}
        for _, page in ipairs(TextBox.paginate(self.footer, 36)) do
          for _, line in ipairs(page) do flat[#flat + 1] = line end
        end
        local y = 112
        for i = math.max(1, #flat - 1), #flat do
          Font.draw(flat[i], 8, y)
          y = y + 16
        end
      end
    elseif self.footer then
      local flat = {}
      for _, page in ipairs(TextBox.paginate(self.footer, 36)) do
        for _, line in ipairs(page) do flat[#flat + 1] = line end
      end
      local y = (#flat >= 2) and 120 or 128
      for i = math.max(1, #flat - 1), #flat do
        Font.draw(flat[i], 16, y)
        y = y + 8
      end
    end

    if self.gen1BetterMenusBagFavorites then
      local hint = "[SELECT] SORT   [START] FAVORITE"
      Font.draw(
        hint,
        math.floor((304 - Font.width(hint)) / 2),
        152
      )
    end
    love.graphics.setColor(1, 1, 1, 1)
  end
end

local function installMenuLayout()
  local originalNew = Menu.new
  local originalUpdate = Menu.update
  local originalOpenMenu = TitleState.openMenu
  local originalTitleNew = TitleState.new
  local originalTitleDraw = TitleState.draw
  local originalTitlePalettes = TitleState.sgbPalettes

  local function startMenuFavorites(save)
    save.gen1BetterMenusStartFavorites =
      save.gen1BetterMenusStartFavorites or {}
    return save.gen1BetterMenusStartFavorites
  end

  local function startMenuKey(item)
    return tostring(item and item.label or "")
  end

  local function sortStartFavorites(menu)
    if not menu.gen1BetterMenusStartFavorites then return end

    local selected = menu.items[menu.index]
    local favorites = startMenuFavorites(menu.game.save)
    local rank = menu.gen1BetterMenusStartRank or {}

    table.sort(menu.items, function(a, b)
      local ak = startMenuKey(a)
      local bk = startMenuKey(b)

      local af = favorites[ak] == true
      local bf = favorites[bk] == true

      if af ~= bf then
        return af
      end

      return (rank[ak] or math.huge) < (rank[bk] or math.huge)
    end)

    if selected then
      for i, item in ipairs(menu.items) do
        if item == selected then
          menu.index = i
          break
        end
      end
    end
  end

  local function drawStartHeart(x, y)
    love.graphics.rectangle("fill", x + 1, y + 1, 2, 1)
    love.graphics.rectangle("fill", x + 4, y + 1, 2, 1)
    love.graphics.rectangle("fill", x, y + 2, 7, 2)
    love.graphics.rectangle("fill", x + 1, y + 4, 5, 1)
    love.graphics.rectangle("fill", x + 2, y + 5, 3, 1)
    love.graphics.rectangle("fill", x + 3, y + 6, 1, 1)
  end

  local function colorizeYellowPikachu(game, source)
    local logo = PaletteFX.effectiveColors(YELLOW_TITLE_LOGO)
    local pika = PaletteFX.effectiveColors(YELLOW_TITLE_PIKACHU)
    if not (logo and pika) then return nil end
	if type(source) == "table" then source = source.path end
	if not source then return nil end
	local path = require("src.render.Assets").resolve(source)
    local ok, data = pcall(love.image.newImageData, path)
    if not ok or not data then return nil end
    local body, accent, ink = logo[2], pika[3], pika[4]
    data:mapPixel(function(_, _, r, g, b, a)
      if r > 0.99 and g > 0.99 and b > 0.99 then
        return 0, 0, 0, 0
      end
      local shade = (r + g + b) / 3
      local color = shade > 0.5 and body or (shade > 0.16 and accent or ink)
      return color[1] / 255, color[2] / 255, color[3] / 255, a
    end)
    local colored = love.graphics.newImage(data)
    colored:setFilter("nearest", "nearest")
    return colored
  end

  local function patchContinueInfo(menu)
    local info = menu.game and menu.game.stack and menu.game.stack:top()
    if not info or info == menu or not info.titleUiBox
       or not info.title or not info.save then return end
    local tw, th = TITLE_PANEL_TW, TITLE_INFO_TH
    local tx, ty = centeredTitlePanel(th)
    info.titleUiBox = { tx, ty, tx + tw - 1, ty + th - 1 }
    info.enhancedTitleInfo = true
    info.uiSize = function() return UI_W, UI_H end
    info.isWideBattleLayout = function() return false end
    info.isOpaque = false
    info.draw = function(self)
      local save = self.save
      local inner = tw - 2
      local badges = require("src.inventory.Badges").count(self.game.data, save)
      local owned = 0
      for _ in pairs(save.pokedex and save.pokedex.owned or {}) do
        owned = owned + 1
      end
      local seconds = math.floor(save.playTime or 0)
      local rows = {
        Strings("PLAYER %s", (save.player and save.player.name) or "RED"),
        Strings("BADGES %d", badges),
        Strings("POKéDEX %d", owned),
        Strings("TIME %d:%02d", math.floor(seconds / 3600),
          math.floor(seconds / 60) % 60),
      }
      Font.drawBox(tx, ty, tw, th)
      love.graphics.setColor(0, 0, 0, 1)
      for i, row in ipairs(rows) do
        Font.draw(truncate(row, inner), (tx + 1) * 8,
          (ty + i * 2 - 1) * 8)
      end
      love.graphics.setColor(1, 1, 1, 1)
    end
  end

  Menu.new = function(game, items, opts)
    opts = opts or {}
    local parent = game and game.stack and game.stack:top()
    local pcMenu = opts.noSound or (parent and parent.gen1BetterMenusPC)
    local centerPCMenu = isCenterPCMenu(items, opts)
    if centerPCMenu then
      local widest = 0
      for _, item in ipairs(items) do
        widest = math.max(widest, #(Font.split(item.label or "")))
      end
      local rowStep = opts.rowStep or 2
      opts.tx = 0
      opts.tw = widest + 3
      opts.th = (#items - 1) * rowStep + 3
      opts.itemY = 1
    end
    local titleMenu = game and game.stack
      and getmetatable(game.stack:top()) == TitleState
    if titleMenu then
      opts.rowStep, opts.th = 1, #items + 2
      opts.tw = TITLE_PANEL_TW
      opts.tx, opts.ty = centeredTitlePanel(opts.th)
    end
    if opts.startCloses then
      local widest = 0
      for _, item in ipairs(items) do
        widest = math.max(widest, #(Font.split(item.label or "")))
      end

      opts.tw = 11
      opts.th = 17
      opts.tx = math.floor((UI_TW - opts.tw) / 2)
      opts.ty = math.floor((UI_TH - opts.th) / 2)
      opts.itemY = 1
      opts.anchor = nil
    end
    local self = originalNew(game, items, opts)

    if opts.startCloses then
      self.tw = 11
      self.gen1BetterMenusStartFavorites = true
      self.gen1BetterMenusStartRank = {}

      for i, item in ipairs(self.items) do
        self.gen1BetterMenusStartRank[startMenuKey(item)] = i
      end

      sortStartFavorites(self)
    end
	parent = game and game.stack and game.stack:top()
	if parent and getmetatable(parent) == ListMenu
      and not self.anchor then
	    if parent.gen1BetterMenusBagFavorites then
	      self.gen1BetterMenusBagSubmenu = true
	      self.uiSize = function() return parent:uiSize() end
	      self.sgbPalettes = parent.sgbPalettes
	    end
	    self.tx = self.tx + (UI_TW - 20)
	    local step = self.rowStep or 2
	    local neededTh = #items * step + 1
	    if self.th and self.th < neededTh then
	      self.th = neededTh
	    end
	    if self.ty and self.th and self.ty + self.th > UI_TH then
	      self.ty = math.max(0, UI_TH - self.th)
	    end
	    self.isWideBattleLayout = function() return false end
	    local drawMenu = self.draw
	    self.isOpaque = false
	    self.sgbPalettes = wholeWide
	    self.draw = function(menu)
		  parent:draw()
		  drawMenu(menu)
		end
	end
    if pcMenu then
      self.gen1BetterMenusPC = true
      self.gen1BetterMenusCenterPC = centerPCMenu
      self.isWideBattleLayout = function() return false end
      if centerPCMenu then
        self.tx = math.floor((UI_TW - self.tw) / 2)
        self.ty = math.floor((UI_TH - self.th) / 2)
      elseif not self.anchor
          and not (parent and getmetatable(parent) == ListMenu) then
        self.tx = self.tx + (UI_TW - 20)
      end
    end
    self.enhancedTitleMenu = titleMenu
    return self
  end

  local originalBoxMenuNew = BoxMenu.new
  BoxMenu.new = function(game)
    local self = originalBoxMenuNew(game)
    self.tx, self.tw = 0, UI_TW
    self.gen1BetterMenusPC = true
    self.gen1BetterMenusPCChrome = true
    self.draw = function(menu)
      if pcOverlayAbove(menu) then return end
      Menu.draw(menu)
      drawPCChrome(game)
    end
    return self
  end

  local originalPlayerPCNew = PlayerPC.new
  PlayerPC.new = function(game, opts)
    local self = originalPlayerPCNew(game, opts)
    self.tx, self.tw = 0, UI_TW
    self.gen1BetterMenusPC = true
    return self
  end

  Menu.update = function(self, dt)
    local titleMenu = self.enhancedTitleMenu

    if self.gen1BetterMenusStartFavorites
        and self.game.input:wasPressed("select") then
      local item = self.items[self.index]

      if item then
        local favorites = startMenuFavorites(self.game.save)
        local key = startMenuKey(item)

        favorites[key] = not favorites[key] or nil

        require("src.core.Sound").play(self.game.data, "Swap")
        sortStartFavorites(self)
      end

      return
    end

    originalUpdate(self, dt)

    if titleMenu then
      patchContinueInfo(self)
    end
  end

  TitleState.openMenu = function(self)
    originalOpenMenu(self)
    local menu = self.game.stack:top()
    if getmetatable(menu) == Menu and menu.enhancedTitleMenu then
      menu.titleUiBox = {
        menu.tx, menu.ty,
        menu.tx + menu.tw - 1, menu.ty + menu.th - 1,
      }
    end
  end

  TitleState.new = function(game, opts)
    local self = originalTitleNew(game, opts)
    if self.yellowLayout then
      local colored = colorizeYellowPikachu(
        game, self.title and self.title.pikachu)
      if colored then
        self.yellowPikachu = colored
        self.enhancedYellowPikachu = true
      end
    end
    return self
  end

  TitleState.draw = function(self)
    local top = self.game and self.game.stack and self.game.stack:top()
    local titleOptions = top and getmetatable(top) == OptionsMenu
    local currentSprite
    if titleOptions then
      -- The wide Options panel completely covers the title canvas. Suppress
      -- the hidden Red/Blue title Pokémon so its true-color redraw rectangle
      -- cannot be replayed over the finished panel during the palette pass.
      top.titleUiBox = { 0, 0, UI_TW - 1, UI_TH - 1 }
      currentSprite = self.currentSprite
      self.currentSprite = function() return nil, false end
    end
    local titlePanel = top and
      (top.enhancedTitleMenu or top.enhancedTitleInfo)
    if titlePanel then
      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.rectangle("fill", 0, 0, UI_W, UI_H)
    else
      originalTitleDraw(self)
    end
    if currentSprite then self.currentSprite = currentSprite end
    local titleVisible = top == self
    if self.enhancedYellowPikachu and titleVisible then
      PaletteFX.markUiSpriteRedraw(
        self.yellowPikachu, nil,
        32, 64 - (self.scy or 0))
    end
  end

  TitleState.sgbPalettes = function(self, game)
    local top = game and game.stack and game.stack:top()
    if top and top.titleUiBox
       and (top.enhancedTitleMenu or top.enhancedTitleInfo) then
      return {
        PaletteFX.zone(effectiveMenuPalette(), 0, 0, UI_TW - 1, UI_TH - 1),
      }
    end
    local result = originalTitlePalettes(self, game)
    if self.yellowLayout and result then
      if result[1] then result[1].colors = YELLOW_TITLE_LOGO end
      if result[2] then result[2].colors = YELLOW_TITLE_PIKACHU end
      if result[3] then result[3].colors = YELLOW_TITLE_LOGO end
      result[#result + 1] = PaletteFX.zone(
        PaletteFX.GRAYS, 0, 17, 19, 17)
    end
    return result
  end

  Menu.uiSize = function() return UI_W, UI_H end
Menu.isWideBattleLayout = function(self)
  local states = self.game and self.game.stack and self.game.stack.states
    or {}
	for i = 1, #states - 1 do
  if states[i] == self and getmetatable(states[i + 1]) == ListMenu then
    return false
  end
end
  for i = 1, #states do
    if states[i] ~= self and states[i] and states[i].isBattle then
      return true
    end
  end

  return false
end
  Menu.isOpaque = false
  local originalMenuDraw = Menu.draw
  Menu.draw = function(self)
  if self.gen1BetterMenusPC and pcOverlayAbove(self) then
    return
  end
  local states = self.game and self.game.stack and self.game.stack.states or {}

  for i = 1, #states - 1 do
    if states[i] == self and getmetatable(states[i + 1]) == ListMenu then
      return
    end
  end
  
  if self.startCloses then
    local originalLabels = {}

    for i, item in ipairs(self.items) do
      originalLabels[i] = item.label
      item.label = truncate(item.label, 8)
    end

    local selectedLabel = originalLabels[self.index]

    if selectedLabel then
      local text = tostring(selectedLabel)
	local spans = Font.split(text)
	local chars = {}

	for _, span in ipairs(spans) do
	  chars[#chars + 1] = text:sub(span.from, span.to)
	end

if #chars > 8 then
        local marqueeEnabled = activeMod and activeMod.options:get("marquee_text") ~= false
        if marqueeEnabled then
          if self.gen1BetterMenusMarqueeIndex ~= self.index then
            self.gen1BetterMenusMarqueeIndex = self.index
            self.gen1BetterMenusMarqueeStart = love.timer.getTime()
          end

          local loop = {}

          for _, char in ipairs(chars) do
            loop[#loop + 1] = char
          end

          loop[#loop + 1] = " "
          loop[#loop + 1] = " "

          local elapsed =
            love.timer.getTime() - (self.gen1BetterMenusMarqueeStart or 0)

          local offset = math.floor(elapsed / 0.20) % #loop
          local visible = {}

          for n = 1, 8 do
            local pos = ((offset + n - 1) % #loop) + 1
            visible[#visible + 1] = loop[pos]
          end

          self.items[self.index].label = table.concat(visible)
        end
      end
    end

    originalMenuDraw(self)

    local favorites = startMenuFavorites(self.game.save)
    local cursorX = (self.tx + 1) * 8
    local itemY = self.itemY or 1
    local rowStep = self.rowStep or 2
    local scroll = self.scroll or 0

    love.graphics.setColor(0, 0, 0, 1)

    for i, item in ipairs(self.items) do
      item.label = originalLabels[i]

      local row = i - scroll

      if row >= 1 and row <= 8
          and i ~= self.index
          and favorites[startMenuKey(item)] then
        local y = (self.ty + itemY + (row - 1) * rowStep) * 8
        drawStartHeart(cursorX, y)
      end
    end

    love.graphics.setColor(1, 1, 1, 1)
    return
  end

  return originalMenuDraw(self)
end

end

local function installBattlePaletteIsolation()
  local originalBlitCanvas = Renderer.blitCanvas

  Renderer.blitCanvas = function(self, canvas, sx, sy, zones, ...)
    if canvas == self.canvas and zones then
      local filtered = {}
      for i = 1, #zones do
        if not zones[i].gen1BetterMenusBattleUI then
          filtered[#filtered + 1] = zones[i]
        end
      end
      zones = filtered
    end
    return originalBlitCanvas(self, canvas, sx, sy, zones, ...)
  end
end

local function battleUIZone(palette, tx1, ty1, tx2, ty2)
  local zone = PaletteFX.zone(palette, tx1, ty1, tx2, ty2)
  zone.gen1BetterMenusBattleUI = true
  return zone
end

local function locationBannerDuration(game)
  local options = game and game.mods and game.mods.modOptions
  local values = options and (options.quality_of_life
    or options["quality-of-life"])
  local duration = values and values.qol_location_banners
  if duration == true then duration = 2 end
  return type(duration) == "number" and duration or nil
end

local function locationBannerName(game, event)
  local mapId = event and event.mapId
  local townMap = game and game.data and game.data.field
    and game.data.field.townMap
  local locations = townMap and (townMap.locations or townMap)
  local entry = type(locations) == "table" and locations[mapId]
  local name = type(entry) == "table" and (entry.name or entry.label)
  local map = event and event.map
  local def = map and map.def
    or (game and game.data and game.data.maps and game.data.maps[mapId])
  if not name and def and type(def.label) == "string" then
    name = def.label:gsub("(%l)(%u)", "%1 %2")
  end
  return tostring(name or mapId or ""):gsub("_", " "):upper()
end

local function drawLocationBanner(world)
  local state = locationStates[world]
  if not state or love.timer.getTime() >= state.expiresAt then return end
  local width = Font.width(state.name)
  local tw = math.min(20, math.max(3, math.ceil(width / 8) + 3))
  local tx = math.floor((20 - tw) / 2)
  Font.drawBox(tx, 15, tw, 3)
  love.graphics.setColor(0, 0, 0, 1)
  Font.draw(state.name, math.floor((160 - width) / 2), 128)
  love.graphics.setColor(1, 1, 1, 1)
end

local function locationBannerSuppressed(game)
  local states = game and game.stack and game.stack.states or {}
  for i = 1, #states do
    if states[i] and states[i].gen1BetterMenusSuppressLocationBanner then
      return true
    end
  end
  return false
end

local function claimLocationOverlay(game, world)
  local overlay = world and rawget(world, LOCATION_OVERLAY_KEY)
  if not overlay then return end
  local record = locationOverlays[overlay]
  if not record then
    record = { original = overlay.draw }
    record.wrapper = function()
      if locationBannerSuppressed(game) then return end
      local state = locationStates[world]
      if state and love.timer.getTime() < state.expiresAt then
        drawLocationBanner(world)
      elseif record.original then
        record.original(world)
      end
    end
    locationOverlays[overlay] = record
  elseif overlay.draw ~= record.wrapper then
    record.original = overlay.draw
  end
  overlay.draw = record.wrapper
end

local function installLocationBanners(mod)
  mod.events:on("map.entered", function(event)
    local game = mod.world and mod.world.game
    local world = mod.world and mod.world:overworld()
    local duration = locationBannerDuration(game)
    if not world or not duration or not event or not event.mapId then return end
    locationStates[world] = {
      name = locationBannerName(game, event),
      expiresAt = love.timer.getTime() + duration,
    }
    claimLocationOverlay(game, world)
  end, -1000)
end

local function updateLocationBanner(game)
  local world = game and game.overworld
  claimLocationOverlay(game, world)
  if locationBannerSuppressed(game) then return false end
  local state = world and locationStates[world]
  return state and love.timer.getTime() < state.expiresAt
end

local function installDialogueLayout()
  local originalNew = TextBox.new
  local originalOpenPC = OverworldState.openPC
  local openingPC = 0

  -- Scope the skipped startup TextBox to the engine's existing openPC flow.
  -- Every caller receives the same behavior, including a physical Pokemon
  -- Center PC and mods that invoke openPC from the Start menu.
  OverworldState.openPC = function(self, ...)
    openingPC = openingPC + 1
    local ok, result = pcall(originalOpenPC, self, ...)
    openingPC = openingPC - 1
    if not ok then error(result, 0) end
    return result
  end

  local function widenSavePanel(game, parent)
    if parent and parent.holdsUIAnchors and parent.openPrompt
        and parent.delay ~= nil and not parent.gen1BetterMenusSavePanel then
      parent.gen1BetterMenusSavePanel = true
      parent.uiSize = function() return UI_W, UI_H end
      parent.isWideBattleLayout = function() return false end
      parent.sgbPalettes = wholeWide
      parent.draw = function()
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.rectangle("fill", 0, 0, UI_W, UI_H)
        local save = game.save
        local badges = require("src.inventory.Badges").count(game.data, save)
        local owned = 0
        for _ in pairs(save.pokedex and save.pokedex.owned or {}) do
          owned = owned + 1
        end
        local seconds = math.floor(save.playTime or 0)
        local rows = {
          { Strings("PLAYER"), (save.player and save.player.name) or "RED" },
          { Strings("BADGES"), tostring(badges) },
          { Strings("POKéDEX"), tostring(owned) },
          { Strings("TIME"), ("%d:%02d"):format(
              math.floor(seconds / 3600), math.floor(seconds / 60) % 60) },
        }
        Font.drawBox(0, 0, UI_TW, 10)
        love.graphics.setColor(0, 0, 0, 1)
        for i, row in ipairs(rows) do
          local y = i * 16
          Font.draw(row[1], 16, y)
          Font.draw(row[2], UI_W - 16 - Font.width(row[2]), y)
        end
        love.graphics.setColor(1, 1, 1, 1)
      end
    end
  end

  local originalPush = StateStack.push
  StateStack.push = function(stack, state, ...)
    -- The Pokemon Center PC builds its menu before pushing the stock
    -- "turned on the PC" TextBox. Run that box's existing completion
    -- callback immediately so the already-built menu opens directly.
    if state and state.gen1BetterMenusSkipCenterPCTurnOn then
      local onDone = state.onDone
      state.onDone = nil
      if onDone then onDone() end
      return
    end

    -- The SAVE panel waits 30 frames before creating its TextBox. Widen it
    -- as it enters the stack so the retained START menu never flashes first.
    widenSavePanel(Game, state)
    return originalPush(stack, state, ...)
  end

  TextBox.new = function(game, text, onDone, opts)
    local self = originalNew(game, text, onDone, opts)
    local centerPCTurnOnText = game and game.data and game.data.text
      and game.data.text._TurnedOnPC1Text
    if openingPC > 0
        and ((centerPCTurnOnText ~= nil and text == centerPCTurnOnText)
        or (centerPCTurnOnText == nil
          and text == "{PLAYER} turned on\nthe PC.")) then
      self.gen1BetterMenusSkipCenterPCTurnOn = true
    end
    local parent = game and game.stack and game.stack:top()
    widenSavePanel(game, parent)
    local inWideBattle, wideBattleState = false, nil
    for _, state in ipairs(game and game.stack and game.stack.states or {}) do
      if state and state.isBattle and state.uiSize then
        local w = state:uiSize()
        if w and w > Renderer.WIDTH then
          inWideBattle, wideBattleState = true, state
          break
        end
      end
    end
    if parent and parent.uiSize then
      local w, h = parent:uiSize()
      if w and w > Renderer.WIDTH then
        self.uiSize = function() return w, h end
        self.isWideBattleLayout = function() return inWideBattle end
        self.holdsUIAnchors = true
      end
    end
    self.boxTx, self.boxTy, self.boxTw, self.boxTh = 0, 13, UI_TW, 5
    self.maxCols = 36
    self.textX, self.line1Y, self.line2Y = 8, 112, 128
    if parent and getmetatable(parent) == OakSpeech then
      -- The dialogue is 304px wide, but OakSpeech still draws its original
      -- 160px scene. Let the engine center that classic scene and its palette
      -- masks inside the wide canvas.
      self.isWideBattleLayout = function() return true end
    end
    if inWideBattle and tostring(text):lower():find("nickname", 1, true)
        and wideBattleState and wideBattleState.enemy
        and wideBattleState.enemy.sprite then
      local originalDraw = self.draw
      self.isOpaque = true
      self.gen1BetterMenusSolidNickname = true
      self.holdsUIAnchors = false
      self.sgbPalettes = function(_, currentGame)
        local base = effectiveMenuPalette()
        local palette = { base[1], base[2], base[3], base[4] }
        local r, g, b = PaletteFX.paperShade(currentGame.data)
        palette[1] = {
          math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5),
          math.floor(b * 255 + 0.5),
        }
        return { PaletteFX.zone(palette, 0, 0, UI_TW - 1, UI_TH - 1) }
      end
      wideBattleState.holdsUIAnchors = false
      self.draw = function(box)
        local sprite = wideBattleState.enemy.sprite
        local sw, sh = sprite:getDimensions()
        local sx, sy = math.floor((UI_W - sw) / 2), 24
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.rectangle("fill", 0, 0, UI_W, UI_H)
        love.graphics.draw(sprite, sx, sy)
        PaletteFX.markTrueColor(sx, sy, sw, sh)
        originalDraw(box)
      end
    end
    -- Reflow after widening and rebuild the typewriter's current line so it
    -- cannot retain the original 18-column first-page split.
    self.pages = TextBox.paginate(TextBox.substitute(game, text), self.maxCols)
    if self.instant then
      self.pageIndex = #self.pages
      local page = self.pages[self.pageIndex] or {}
      self.shown = {}
      for index = math.max(1, #page - 1), #page do
        self.shown[#self.shown + 1] = Font.encode(page[index])
      end
      self.lineIndex = #page
      self.codes = self.shown[#self.shown] or {}
      self.charIndex = #self.codes
    else
      self.pageIndex, self.lineIndex, self.charIndex = 1, 1, 0
      self.shown = {}
      self:beginLine()
    end
    return self
  end
  makeWideState(TextBox)

  local choiceNew = ChoiceBox.new
  ChoiceBox.new = function(game, onChoose, opts)
    local self = choiceNew(game, onChoose, opts)
    self.tx = UI_TW - self.tw
    return self
  end
  makeWideState(ChoiceBox)
end

local function installSupportingScreens()

	DexEntryMenu.sgbPalettes = function(self, game)
	  local base = PaletteFX.pal(game.data, "BROWNMON")
	  if not base then return nil end
	  local ox = math.floor((UI_W - 160) / 2) / 8

	  return {
	  -- The entry renderer is translated into the centre of the 304px canvas;
	  -- its palette zones must follow the same translation.
	  PaletteFX.zone(base, ox, 0, ox + 9, 17),
	  PaletteFX.zone(base, ox + 10, 0, ox + 19, 17),

	  -- Pokémon sprite palette.
	  PaletteFX.zone(
		PaletteFX.monPal(game.data, self.def and self.def.id),
		ox + 1,
		1,
		ox + 8,
		8
	  ),

	  -- Active menu palette on the Pokédex frame only.
	  PaletteFX.zone(effectiveMenuPalette(), ox, 0, ox + 9, 0),         -- top-left
	  PaletteFX.zone(effectiveMenuPalette(), ox + 10, 0, ox + 19, 0),   -- top-right
	  PaletteFX.zone(effectiveMenuPalette(), ox, 17, ox + 9, 17),       -- bottom-left
	  PaletteFX.zone(effectiveMenuPalette(), ox + 10, 17, ox + 19, 17), -- bottom-right
	  PaletteFX.zone(effectiveMenuPalette(), ox, 0, ox, 17),            -- left
	  PaletteFX.zone(effectiveMenuPalette(), ox + 19, 0, ox + 19, 17),  -- right
	  PaletteFX.zone(effectiveMenuPalette(), ox, 9, ox + 9, 9),         -- divider-left
	  PaletteFX.zone(effectiveMenuPalette(), ox + 10, 9, ox + 19, 9),   -- divider-right
	}
	end

	DexEntryMenu.uiSize = function()
	  return UI_W, UI_H
	end

	DexEntryMenu.isWideBattleLayout = function()
	  return true
	end

	DexEntryMenu.isOpaque = false
	
	
	local originalDexEntryDraw = DexEntryMenu.draw

	DexEntryMenu.draw = function(self)
	  -- The Dex renderer still inherits the classic 160px clip.
	  -- Remove it while drawing the centered page.
	  love.graphics.setScissor()
	  love.graphics.setColor(1, 1, 1, 1)
	  love.graphics.rectangle("fill", 0, 0, UI_W, UI_H)

	  love.graphics.push()
	  love.graphics.translate(72, 0)
	  PaletteFX.setMarkOffset(72)
	  originalDexEntryDraw(self)
	  PaletteFX.setMarkOffset(0)
	  love.graphics.pop()
	  love.graphics.setScissor()
	end

  TrainerCard.isOpaque = false
  TrainerCard.sgbPalettes = wholeWide

  local function clearWideBattleHudTrueColor()
    local rects = PaletteFX.trueColorRects("ui")
    for i = #rects, 1, -1 do
      local rect = rects[i]
      local enemyHP = rect.x == 8 and rect.y == 16 and rect.w == 112 and rect.h == 8
      local playerHP = rect.x == 192 and rect.y == 72 and rect.w == 112 and rect.h == 8
      local playerExp = rect.x == 192 and rect.y == 88 and rect.w == 104 and rect.h == 8
      if enemyHP or playerHP or playerExp then
        table.remove(rects, i)
      end
    end
  end

  local originalNamingNew = NamingScreen.new
  NamingScreen.new = function(game, opts)
    local self = originalNamingNew(game, opts)
    local wideBattle, introNaming = false, false
    local introAnchors = {}
    for _, state in ipairs(game and game.stack and game.stack.states or {}) do
      if getmetatable(state) == OakSpeech then introNaming = true end
      if state and state.isBattle and state.uiSize then
        local w = state:uiSize()
        if w and w > Renderer.WIDTH then wideBattle = true break end
      end
    end
    if wideBattle or self.mon then
      self.gen1BetterMenusSolidNickname = true
      self.uiSize = function() return UI_W, UI_H end
      self.isWideBattleLayout = function() return true end
      self.sgbPalettes = function(_, currentGame)
        local base = effectiveMenuPalette()
        local palette = { base[1], base[2], base[3], base[4] }
        local r, g, b = PaletteFX.paperShade(currentGame.data)
        palette[1] = {
          math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5),
          math.floor(b * 255 + 0.5),
        }
        return { PaletteFX.zone(palette, 0, 0, UI_TW - 1, UI_TH - 1) }
      end
      self.draw = function(screen)
        if screen.choosing then return end
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.rectangle("fill", 0, 0, UI_W, UI_H)
        love.graphics.push()
        love.graphics.translate(math.floor((UI_W - Renderer.WIDTH) / 2), 0)

        -- 1. Keyboard box (tx = 0, ty = 1, tw = 21, th = 12) shifted upward by 4px
        love.graphics.push()
        love.graphics.translate(0, -4)
        Font.drawBox(0, 1, 21, 12)

        local rowY = { 20, 34, 47, 61, 74, 88 }
        love.graphics.setColor(0, 0, 0, 1)
        for r, row in ipairs(screen:grid()) do
          local y = rowY[r] or (r * 14)
          for c, cell in ipairs(row) do
            Font.draw(Strings(cell), c * 16, y)
          end
        end
        local curY = rowY[screen.row] or (screen.row * 14)
        if screen.row < #screen:grid() then
          Font.drawCode(Theme.cursor, screen.col * 16 - 8, curY)
        else
          Font.drawCode(Theme.cursor, 8, curY)
        end
        love.graphics.pop()

        -- 2. Lower-left Pokémon battle front sprite
        local mon = screen.mon or self.mon
        if mon then
          local Assets = require("src.render.Assets")
          local Sprites = require("src.pokemon.Sprites")
          local path, trueColor = Sprites.path(game.data, mon.species, "front", { mon = mon, kind = "battle" })
          local ok, img = pcall(Assets.image, path)
          if ok and img then
            local sw, sh = img:getDimensions()
            local sx = 21
            local sy = 101
            if not trueColor then
              local monPal = PaletteFX.monPal(game.data, mon.species)
              local shader = monPal and PaletteFX.shader()
              if shader then
                PaletteFX.sendColors(shader, monPal)
                love.graphics.setShader(shader)
              end
              love.graphics.setColor(1, 1, 1, 1)
              love.graphics.draw(img, sx, sy)
              if shader then love.graphics.setShader() end
            else
              love.graphics.setColor(1, 1, 1, 1)
              love.graphics.draw(img, sx, sy)
            end
            PaletteFX.markTrueColor(sx + math.floor((UI_W - Renderer.WIDTH) / 2), sy, sw, sh)
          else
            PartyMenu.drawIcon(game, mon, 21, 101, false, 0)
          end

          -- 3. Species name to the right of sprite
          local def = game.data.pokemon and game.data.pokemon[mon.species]
          local name = def and def.name or mon.species or ""
          love.graphics.setColor(0, 0, 0, 1)
          Font.draw(name, 67, 104)
        end

        -- 4. NICKNAME? below species name with '?' moved up by 1 pixel
        love.graphics.setColor(0, 0, 0, 1)
        local title = screen.title or "NICKNAME?"
        if title:sub(-1) == "?" then
          local prefix = title:sub(1, #title - 1)
          Font.draw(prefix, 67, 115)
          Font.draw("?", 67 + Font.width(prefix), 114)
        else
          Font.draw(title, 67, 115)
        end

        -- 5. Nickname entry line shifted right by approx 20px
        local maxLen = screen.maxLen or 10
        local slotStartX = math.floor((160 - maxLen * 8) / 2) + 26
        for i = 1, maxLen do
          Font.draw(screen.glyphs[i] or "-", slotStartX + (i - 1) * 8, 132)
        end
        love.graphics.setColor(1, 1, 1, 1)

        love.graphics.pop()
        clearWideBattleHudTrueColor()
      end
    elseif introNaming then
      -- Oak's held dialogue remains below this screen and would otherwise
      -- split the naming UI at its bottom anchor. Temporarily release only
      -- that retained dialogue anchor while the naming screen is active.
      for _, state in ipairs(game and game.stack and game.stack.states or {}) do
        if state and state.isTextBox then
          introAnchors[#introAnchors + 1] = {
            state = state,
            holdsUIAnchors = state.holdsUIAnchors,
            isWideBattleLayout = state.isWideBattleLayout,
          }
          state.holdsUIAnchors = false
          state.isWideBattleLayout = function() return false end
        end
      end
      local originalOnDone = self.onDone
      self.onDone = function(...)
        for _, anchor in ipairs(introAnchors) do
          anchor.state.holdsUIAnchors = anchor.holdsUIAnchors
          anchor.state.isWideBattleLayout = anchor.isWideBattleLayout
        end
        introAnchors = {}
        if originalOnDone then return originalOnDone(...) end
      end
      local originalDraw = self.draw
      self.gen1BetterMenusIntroNaming = true
      self.isOpaque = true
      self.uiSize = function() return UI_W, UI_H end
      self.isWideBattleLayout = function() return true end
      self.letterboxWhite = true
      self.sgbPalettes = wholeWide
      local originalEnter = self.enter
      self.enter = function(screen, ...)
        originalEnter(screen, ...)
        -- The preset list is an overlay on this naming screen. Keep this
        -- solid canvas opaque so Oak's held scene/dialogue cannot supply a
        -- displaced palette field behind either player's or rival's list.
        screen.isOpaque = true
      end
      self.draw = function(screen)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.rectangle("fill", 0, 0, UI_W, UI_H)
        love.graphics.push()
        love.graphics.translate(math.floor((UI_W - Renderer.WIDTH) / 2), 0)
        originalDraw(screen)
        love.graphics.pop()
      end
    end
    return self
  end

  local function partySlot(i)
    local col = math.floor((i - 1) / 3)
    local row = (i - 1) % 3
    return 8 + col * 144, 10 + row * 40
  end

  local function addPaletteZoneOutside(zones, colors, rect, cutout)
    if not cutout then
      zones[#zones + 1] = {
        colors = colors, x = rect.x, y = rect.y, w = rect.w, h = rect.h,
      }
      return
    end

    local x1, y1 = rect.x, rect.y
    local x2, y2 = x1 + rect.w, y1 + rect.h
    local cx1, cy1 = cutout.x, cutout.y
    local cx2, cy2 = cx1 + cutout.w, cy1 + cutout.h
    local ix1, iy1 = math.max(x1, cx1), math.max(y1, cy1)
    local ix2, iy2 = math.min(x2, cx2), math.min(y2, cy2)

    if ix1 >= ix2 or iy1 >= iy2 then
      zones[#zones + 1] = {
        colors = colors, x = x1, y = y1, w = rect.w, h = rect.h,
      }
      return
    end

    local function add(x, y, w, h)
      if w > 0 and h > 0 then
        zones[#zones + 1] = {
          colors = colors, x = x, y = y, w = w, h = h,
        }
      end
    end

    add(x1, y1, rect.w, iy1 - y1)
    add(x1, iy2, rect.w, y2 - iy2)
    add(x1, iy1, ix1 - x1, iy2 - iy1)
    add(ix2, iy1, x2 - ix2, iy2 - iy1)
  end

  local inkShader
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

  local function paneBackgroundColor(game)
    local menuPal = effectiveMenuPalette(game)
    if menuPal and menuPal[1] then
      local c = PaletteFX.effectiveColors(menuPal) or menuPal
      return { c[1][1] / 255, c[1][2] / 255, c[1][3] / 255, 1 }
    end
    return { 1, 1, 1, 1 }
  end

  local function getGenderModApi(game)
    local handle = (activeMod and activeMod.find and activeMod.find("gender_mod"))
      or (game and game.mods and game.mods.find and game.mods:find("gender_mod"))
    if handle and handle.exports then return handle.exports end
    local exports = (game and game.mods and game.mods.exports)
      or (Runtime and Runtime.mods and Runtime.mods.exports)
    return exports and exports["gender_mod"]
  end

  local function drawPartyGender(game, mon, x, y, menu)
    local api = getGenderModApi(game)
    if not api or type(api.genderOf) ~= "function" then return end
    local okGender, gender = pcall(api.genderOf, mon)
    if not okGender or not gender then return end

    local state = api.state and api.state(gender) or (type(gender) == "table" and gender.state or gender)
    local color = { 0, 0, 0, 1 }
    if type(api.palette) == "function" then
      local okPalette, exported = pcall(api.palette, gender)
      if okPalette and type(exported) == "table" then color = exported end
    elseif state == "M" then
      color = { 32 / 255, 104 / 255, 224 / 255, 1 }
    elseif state == "F" then
      color = { 248 / 255, 72 / 255, 152 / 255, 1 }
    end

    local bg = paneBackgroundColor(game)
    x, y = math.floor(x), math.floor(y)

    love.graphics.setColor(bg[1], bg[2], bg[3], 1)
    love.graphics.rectangle("fill", x, y, 8, 8)

    local okSymbol, symbol = pcall(api.symbol or function(g)
      return g == "M" and "♂" or g == "F" and "♀" or "⚲"
    end, gender)
    if okSymbol and type(symbol) == "string" and symbol ~= "" then
      love.graphics.push("all")
      local shader = shaderForInk()
      if shader then love.graphics.setShader(shader) end
      love.graphics.setColor(color[1] or 0, color[2] or 0, color[3] or 0, color[4] or 1)
      Font.draw(symbol, x, y)
      love.graphics.pop()
    end

    local top = game and game.stack and game.stack:top()
    local skipTrueColor = false

    if top and menu and top ~= menu then
      local topW = top.uiWidth or 160
      local topH = top.uiHeight or 144
      if x < topW and y < topH then
        skipTrueColor = true
      end
    end

    if menu and menu.submenu then
      local n = #(menu.subItems or {})
      local smX = (UI_TW - 11) * 8
      local smY = (17 - n * 2 - 1) * 8
      local smW = 11 * 8
      local smH = (n * 2 + 1) * 8
      if x + 8 > smX and x < smX + smW and y + 8 > smY and y < smY + smH then
        skipTrueColor = true
      end
    end

    if not skipTrueColor then
      local okP, PaletteFX = pcall(require, "src.render.PaletteFX")
      if okP and PaletteFX and PaletteFX.markTrueColor then
        PaletteFX.markTrueColor(x, y, 8, 8)
      end
    end
    love.graphics.setColor(1, 1, 1, 1)
  end

  local function drawSmallLevelL(x, y)
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.rectangle("fill", x, y + 2, 2, 5)
    love.graphics.rectangle("fill", x + 2, y + 6, 2, 1)
  end

  makeWideState(PartyMenu)
  PartyMenu.sgbPalettes = function(self, game)
    local zones = wholeWide()
    local submenuCutout
    if self.submenu then
      local n = #self.subItems
      submenuCutout = {
        x = (UI_TW - 11) * 8,
        y = (17 - n * 2 - 1) * 8,
        w = 11 * 8,
        h = (n * 2 + 1) * 8,
      }
    end
    if not self.tmhm then
      local party = self.party or (game.save and game.save.party) or {}
      for i, mon in ipairs(party) do
        local x, y = partySlot(i)
        local hp = mon.hp
        if self.heal and self.heal.mon == mon then hp = self.heal.from end
        local bar = PaletteFX.pal(game.data,
          PaletteFX.barPalName(hp, mon.stats.hp))
        if bar then
          local barX = x + 5 * 8
          local barY = y + 19
          addPaletteZoneOutside(zones, bar, {
            x = barX, y = barY, w = 4 * 8, h = 2,
          }, submenuCutout)
        end
      end
    end
    return zones
  end
  PartyMenu.draw = function(self)
    drawOuterFrame()
    local party = self.party or self.game.save.party
    local HudTiles = require("src.render.HudTiles")
    local barZoned = PaletteFX.shader() ~= nil
      and PaletteFX.pal(self.game.data, "GREENBAR") ~= nil
    if #party == 0 then Font.draw(Strings("No POKéMON!"), 16, 66) end

    for i, mon in ipairs(party) do
      local x, y = partySlot(i)
      local def = self.game.data.pokemon[mon.species]
      love.graphics.setColor(1, 1, 1, 1)
      PartyMenu.drawIcon(self.game, mon, x + 7, y,
                         i == self.index, self.blink or 0)
      love.graphics.setColor(0, 0, 0, 1)

      local rawName = mon.nickname or (def and def.name) or tostring(mon.species or "")
      local gApi = getGenderModApi(self.game)
      local cleanName = rawName
      if gApi and gApi.stripEmbedded then
        cleanName = gApi.stripEmbedded(rawName)
      elseif gApi and gApi.Gender and gApi.Gender.stripEmbedded then
        cleanName = gApi.Gender.stripEmbedded(rawName)
      else
        cleanName = cleanName:gsub("♂", ""):gsub("♀", "")
      end
      local nameText = truncate(cleanName, 10)
      Font.draw(nameText, x + 24, y)
      drawPartyGender(self.game, mon, x + 26 + Font.width(nameText), y, self)
      love.graphics.setColor(0, 0, 0, 1)

      local showLevel = true
      local okLevel, LevelDisplay = pcall(require, "src.ui.LevelDisplay")
      if okLevel and LevelDisplay and LevelDisplay.visible then
        showLevel = LevelDisplay.visible(mon, "party", self.game)
      end
      if showLevel then
        drawSmallLevelL(x + 24, y + 8)
        Font.draw(tostring(mon.level), x + 30, y + 8)
      end

      if self.tmhm or self.evoStone then
        local can = false
        if self.tmhm then
          for _, move in ipairs(def.tmhm or {}) do
            if move == self.tmhm.move then can = true break end
          end
        else
          for _, evo in ipairs(def.evolutions or {}) do
            if evo.method == "ITEM" and evo.item == self.evoStone then
              can = true break
            end
          end
        end
        local label = Strings(can and "ABLE" or "NOT ABLE")
        Font.draw(label, x + 136 - Font.width(label), y + 8)
      else
        local status = mon.hp <= 0 and Strings("FNT") or mon.status
        if status then Font.draw(status, x + 136 - Font.width(status), y + 24) end
        local shown = mon
        if self.heal and self.heal.mon == mon then
          shown = { hp = math.floor(self.heal.shown), stats = mon.stats }
        end
        love.graphics.setColor(1, 1, 1, 1)
        HudTiles.drawHPBar(self.game.data, x / 8 + 3, (y + 16) / 8,
                           shown, nil, barZoned, 4)
        love.graphics.setColor(0, 0, 0, 1)
        local hp = ("%3d/%3d"):format(shown.hp, mon.stats.hp)
        Font.draw(hp, x + 136 - Font.width(hp), y + 16)
      end

      if i == self.index then Font.drawCode(Theme.cursor, x, y + 16) end
      if (i == self.swapFrom or i == self.softboiledFrom) and i ~= self.index then
        Font.drawCode(Theme.cursorHollow, x, y + 16)
      end
    end

    love.graphics.setColor(0, 0, 0, 1)
    local rawBottomMsg = tostring(self:bottomMessage() or "")
    local cleanBottomMsg = rawBottomMsg:gsub("%.+$", ""):gsub("%.(\n)", "%1")
    local flat = {}
    for _, page in ipairs(TextBox.paginate(cleanBottomMsg, 34)) do
      for _, line in ipairs(page) do
        flat[#flat + 1] = tostring(line or ""):gsub("%.+$", "")
      end
    end
    local y = #flat > 1 and 112 or 128
    for i = math.max(1, #flat - 1), #flat do
      local line = tostring(flat[i] or ""):gsub("%.+$", "")
      Font.draw(line, 16, y)
      y = y + 16
    end

    if self.submenu then
      local n = #self.subItems
      local tx = UI_TW - 11
      Font.drawBox(tx, 17 - n * 2 - 1, 11, n * 2 + 1)
      local y0 = (17 - n * 2) * 8
      for si, entry in ipairs(self.subItems) do
        Font.draw(entry.label, (tx + 2) * 8, y0 + (si - 1) * 16)
      end
      Font.drawCode(Theme.cursor, (tx + 1) * 8,
                    y0 + (self.subIndex - 1) * 16)
    end
    drawFrameOnly(0, 0, UI_TW, UI_TH)
    love.graphics.setColor(1, 1, 1, 1)
  end
  -- Rare Candy level-up stat box: inherit the wide menu canvas and
  -- move the stock 11-tile stats window into the added right-hand space.
  local StatBox = BattleState.StatBox
  local originalStatBoxNew = StatBox.new
  local originalStatBoxDraw = StatBox.draw

  StatBox.new = function(game, mon, onDone)
    local self = originalStatBoxNew(game, mon, onDone)

    local parent = game and game.stack and game.stack:top()
    if parent and parent.uiSize then
      local w, h = parent:uiSize()
      if w and w > Renderer.WIDTH then
        self.uiSize = function() return w, h end
        self.gen1BetterMenusWide = true
      end
    end

    return self
  end

  StatBox.draw = function(self)
    if self.gen1BetterMenusWide then
      love.graphics.push()
      love.graphics.translate(UI_W - Renderer.WIDTH, 0)
      originalStatBoxDraw(self)
      love.graphics.pop()
      return
    end

    originalStatBoxDraw(self)
  end
  
  local originalSummaryDraw = SummaryMenu.draw

SummaryMenu.draw = function(self)
  local sprite = self.sprite
  self.sprite = nil
  originalSummaryDraw(self)
  self.sprite = sprite

  if self.page == 1 and self.mon then
    drawPartyGender(self.game, self.mon, 104, 16, self)
  end
end
  
  makeWideState(SummaryMenu)
  SummaryMenu.sgbPalettes = function(self, game)
    local zones = wholeWide()

    -- Summary Pokémon HP bar.
    if self.page == 1 and self.mon and self.mon.stats then
      local bar = PaletteFX.pal(
        game.data,
        PaletteFX.barPalName(self.mon.hp, self.mon.stats.hp)
      )

      if bar then
        zones[#zones + 1] = {
          colors = bar,
          x = 104,
          y = 27,
          w = 48,
          h = 2,
        }
      end
    end

    return zones
  end
end

local function installManagerLayout()
  makeWideState(ManagerState)
  ManagerState.sgbPalettes = wholeWide

  local function drawCut(text, x, y, cols)
    Font.draw(truncate(text, cols), x, y)
  end

  ManagerState.drawRows = function(self, rows)
    local listTop, listRows = 3, 11
    local last = math.min(#rows, self.scroll + listRows - 1)
    local y = listTop
    for i = self.scroll, last do
      local row = rows[i]
      if row.header then
        drawCut(row.label, 16, y * 8, 34)
      else
        if row.glyph and row.glyph ~= " " then Font.draw(row.glyph, 16, y * 8) end
        drawCut(row.label, 32, y * 8, 32)
        if i == self.cursor then Font.drawCode(Theme.cursor, 8, y * 8) end
      end
      y = y + 1
    end
    if #rows > last then
      Font.drawCode(Theme.moreArrow, (UI_TW - 2) * 8,
                    (listTop + listRows) * 8)
    end
  end

  ManagerState.drawFooter = function(self, line1, line2)
    if self.notice then
      drawCut(self.notice, 16, 16 * 8, 34)
      return
    end
    if line2 then
      if line1 then drawCut(line1, 16, 15 * 8, 34) end
      drawCut(line2, 16, 16 * 8, 34)
    elseif line1 then
      drawCut(line1, 16, 16 * 8, 34)
    end
  end

  ManagerState.drawDetail = function(self)
    local m = self.currentMod
    if not m then return end
    drawCut((m.name or m.id) .. " " .. (m.version or ""), 16, 2 * 8, 34)
    local status = m.enabled and "ENABLED" or "DISABLED"
    if m.state == "wrong_generation" or not self:runsHere(m) then
      status = status .. " (NOT THIS GAME)"
    elseif m.state == "blocked_dependency" then
      status = status .. " ?"
    elseif m.error then
      status = status .. " !"
    end
    if self:isStaged(m) then status = status .. " (STAGED)" end
    drawCut(status, 16, 3 * 8, 34)
    drawCut((m.category or "OTHER") .. " / " .. (m.profile or "content"),
            16, 4 * 8, 34)
    local lines = wrapText(m.error and ("FAILED: " .. m.error)
      or (m.note and ("SKIPPED: " .. m.note)) or m.description, 34)
    for i = 1, 5 do
      local line = lines[self.descScroll + i - 1]
      if not line then break end
      Font.draw(line, 16, (5 + i) * 8)
    end
    if self.descScroll + 5 <= #lines then
      Font.drawCode(Theme.moreArrow, (UI_TW - 3) * 8, 10 * 8)
    end
    local rows = self:rowsForScreen()
    local visible = 5
    local first = math.max(1, self.cursor - visible + 1)
    first = math.min(first, math.max(1, #rows - visible + 1))
    for slot = 1, visible do
      local i = first + slot - 1
      local row = rows[i]
      if not row then break end
      drawCut(row.label, 32, (10 + slot) * 8, 32)
      if i == self.cursor then
        Font.drawCode(Theme.cursor, 24, (10 + slot) * 8)
      end
    end
    if first + visible - 1 < #rows then
      Font.drawCode(Theme.moreArrow, (UI_TW - 3) * 8, 15 * 8)
    end
    self:drawFooter("A:CHOOSE B:BACK")
  end

  ManagerState.drawApply = function(self)
    drawCut("PENDING CHANGES", 16, 2 * 8, 34)
    local staged = self:stagedList()
    local y = 3
    for i = 1, math.min(#staged, 7) do
      local m = staged[i]
      drawCut((m.enabled and "ON " or "OFF ") .. (m.name or m.id),
              16, y * 8, 34)
      y = y + 1
    end
    if #staged == 0 then
      Font.draw(Runtime.safeMode and "SAFE MODE" or Strings("NO CHANGES"),
                16, y * 8)
    end
    local rows = self:rowsForScreen()
    for i, row in ipairs(rows) do
      drawCut(row.label, 32, (11 + i) * 8, 32)
      if i == self.cursor then Font.drawCode(Theme.cursor, 24, (11 + i) * 8) end
    end
    self:drawFooter("A:CHOOSE B:BACK")
  end

  ManagerState.drawOverlay = function(self)
    local overlay = self.overlay
    local lines = {}
    for _, raw in ipairs(overlay.lines) do
      for _, line in ipairs(wrapText(raw, 26)) do lines[#lines + 1] = line end
    end
    local tw = 30
    local th = math.max(6, #lines + (overlay.kind == "confirm" and 5 or 3))
    local tx = math.floor((UI_TW - tw) / 2)
    local ty = math.max(1, math.floor((UI_TH - th) / 2))
    Font.drawBox(tx, ty, tw, th)
    love.graphics.setColor(0, 0, 0, 1)
    for i, line in ipairs(lines) do Font.draw(line, (tx + 2) * 8, (ty + i) * 8) end
    if overlay.kind == "confirm" then
      local yesY = ty + #lines + 1
      Font.draw(Strings("YES"), (tx + 3) * 8, yesY * 8)
      Font.draw(Strings("NO"), (tx + 3) * 8, (yesY + 1) * 8)
      Font.drawCode(Theme.cursor, (tx + 2) * 8,
                    (overlay.index == 1 and yesY or yesY + 1) * 8)
    else
      Font.draw(Strings("A:OK"), (tx + 3) * 8, (ty + #lines + 1) * 8)
    end
  end

  ManagerState.draw = function(self)
    if self.screen == "options" then
      OptionRows.draw(self.game, self.optionRows or {}, self.cursor,
                      self.scroll or 0)
      love.graphics.setColor(0, 0, 0, 1)
      drawCut(self.notice or Strings("B:DONE (NO RESTART)"), 16, 16 * 8, 34)
      if self.overlay then self:drawOverlay() end
      love.graphics.setColor(1, 1, 1, 1)
      return
    end
    drawOuterFrame(self.banner or "MOD MANAGER")
    if self.screen == "list" then
      self:drawList()
    elseif self.screen == "detail" then
      self:drawDetail()
    elseif self.screen == "permissions" then
      self:drawPermissions()
    elseif self.screen == "errors" then
      self:drawErrors()
    elseif self.screen == "apply" then
      self:drawApply()
    end
    if self.overlay then self:drawOverlay() end
    love.graphics.setColor(1, 1, 1, 1)
  end
end

local function installLinkLayout()
  local originalDraw = LinkState.draw
  makeWideState(LinkState)
  LinkState.sgbPalettes = wholeWide
  LinkState.draw = function(self)
    drawOuterFrame()
    if self.stage == "menu" then
      local title = Strings("BOIS CLUB LIVE")
      local entries = {
        Strings("LINK CABLE (LAN)"),
        Strings("ONLINE MATCH"),
        Strings("TOURNAMENT"),
      }
      Font.draw(title, (UI_W - Font.width(title)) / 2, 24)
      for i, label in ipairs(entries) do
        Font.draw(label, 112, 56 + (i - 1) * 16)
      end
      Font.drawCode(Theme.cursor, 104, 56 + (self.index - 1) * 16)
      drawFrameOnly(0, 0, UI_TW, UI_TH)
      love.graphics.setColor(1, 1, 1, 1)
      return
    end
    love.graphics.push()
    -- Keep one empty text row between the outer frame and Link's heading.
    love.graphics.translate((UI_W - 160) / 2, 16)
    originalDraw(self)
    love.graphics.pop()
    drawFrameOnly(0, 0, UI_TW, UI_TH)
    love.graphics.setColor(1, 1, 1, 1)
  end
end

return function(mod, menuColors)
  activeMod = mod

  local qolCompatGame
  local enforcingQolBattleGate = false

  local function qolBattleGateReason(game)
    return modernBattleUIMode() == "on" and "MODERN BATTLE UI" or nil
  end

  local function optionValue(loader, modId, key)
    local stored = loader and loader.modOptions and loader.modOptions[modId]
    if stored and stored[key] ~= nil then return stored[key] end
    for _, row in ipairs(loader and loader.optionSchemas
        and loader.optionSchemas[modId] or {}) do
      if row.key == key then return row.default end
    end
    return nil
  end

  local function persistGameOptions(game)
    if game.writeOptions then
      game:writeOptions()
    elseif game.persistOptions then
      game:persistOptions()
    end
  end

  local function enforceQolBattleGate(game)
    if enforcingQolBattleGate or not game
        or modernBattleUIMode() ~= "on" then return false end
    enforcingQolBattleGate = true

    local options = game.save and game.save.options
    local baseOptionsChanged = false
    if options then
      if options.battleLayout ~= "wide" then
        options.battleLayout = "wide"
        baseOptionsChanged = true
      end
      if options.battleHud ~= "extended" then
        options.battleHud = "extended"
        baseOptionsChanged = true
      end
    end
    if baseOptionsChanged then persistGameOptions(game) end

    local manager = ManagerState.new(game)
    local loader = game.mods
    if mod.find("quality_of_life") then
      if optionValue(loader, "quality_of_life", "qol_caught_indicator")
          ~= "off" then
        manager:setOption("quality_of_life", "qol_caught_indicator", "off")
      end
      if optionValue(loader, "quality_of_life", "qol_exp_bar") ~= "off" then
        manager:setOption("quality_of_life", "qol_exp_bar", "off")
      end
    end
    enforcingQolBattleGate = false
    return true
  end

  local function initializeBattleUiCompatibility(game)
    if not game then return end
    enforceQolBattleGate(game)
  end

  mod.events:on("game.ready", function(event)
    qolCompatGame = event and event.game
    activeGame = qolCompatGame
    initializeBattleUiCompatibility(qolCompatGame)
  end)
  mod.events:on("mod.options_changed", function(event)
    if event and event.mod == "gen1-better-menus"
        and event.key == "modern_battle_ui" then
      enforceQolBattleGate(qolCompatGame)
    end
    if event and event.mod == "quality_of_life"
        and (event.key == "qol_caught_indicator"
          or event.key == "qol_exp_bar") then
      enforceQolBattleGate(qolCompatGame)
    end
  end)

  mod.hooks:wrap("ui.options.rows", function(next, game, rows)
    local out = next(game, rows)
    for _, row in ipairs(out or {}) do
      if (row.id == "battleLayout" or row.id == "battleHud")
          and type(row.step) == "function" then
        local step = row.step
        row.step = function(g, ...)
          local result = step(g, ...)
          enforceQolBattleGate(g)
          return result
        end
      end
    end
    return out
  end)

  ManagerState.gen1BetterMenusQolBattleControl = {
    reason = qolBattleGateReason,
    enforce = enforceQolBattleGate,
  }

  local function decorateQolBattleGate(screen)
    if not screen or screen.__gen1BetterMenusQolBattleGate then return screen end
    local update = screen.update
    if type(update) ~= "function" then return screen end

    for _, row in ipairs(screen.rows or {}) do
      if row.key == "qol_caught_indicator" or row.key == "qol_exp_bar" then
        local value = row.value
        row.value = function(g)
          local control = ManagerState.gen1BetterMenusQolBattleControl
          local reason = control and control.reason(g)
          return reason and "OFF (MODERN BATTLE UI)" or value(g)
        end
      end
    end

    screen.update = function(self, ...)
      local input = self.game and self.game.input
      if input and (input:wasPressed("up") or input:wasPressed("down")) then
        return update(self, ...)
      end
      local control = ManagerState.gen1BetterMenusQolBattleControl
      local reason = control and control.reason(self.game)
      local row = self.rows and self.rows[self.index]
      local gated = reason and row
        and (row.key == "qol_caught_indicator" or row.key == "qol_exp_bar")
      if reason then control.enforce(self.game) end
      if gated and input and (input:wasPressed("a")
          or input:wasPressed("left") or input:wasPressed("right")) then
        self.game.stack:push(TextBox.new(self.game,
          "To use the QOL XP Bar or\n" ..
          "Pokedex Indicator, please disable\f" ..
          "BetterMenus Modern Battle UI.\n" ..
          "Modern Battle UI already includes\f" ..
          "an XP bar, Pokedex indicator, and\n" ..
          "extended UI support."))
        return true
      end
      local result = update(self, ...)
      if reason then control.enforce(self.game) end
      return result
    end
    screen.__gen1BetterMenusQolBattleGate = true
    return screen
  end

  local function installQolBattleStackGate(game)
    local stack = game and game.stack
    if not stack then return end
    stack.gen1BetterMenusDecorateQolBattleGate = decorateQolBattleGate
    if stack.__gen1BetterMenusQolBattlePush then return end

    local push = stack.push
    stack.push = function(self, state, ...)
      if state and state.screenId == "QualityOfLife" then
        local decorate = self.gen1BetterMenusDecorateQolBattleGate
        if decorate then decorate(state) end
      end
      return push(self, state, ...)
    end
    stack.__gen1BetterMenusQolBattlePush = true
  end
  mod.events:on("game.ready", function(event)
    installQolBattleStackGate(event and event.game)
  end)

    local genderMod = mod.find("gender_mod")
  local genderExports = genderMod and genderMod.exports or nil

  local compatibility = {
    hgssSprites = mod.find("HGSS_SPRITES") ~= nil,
  }

  local source, readErr = mod:read("screen.lua")
  if not source then
    mod.log:error("screen.lua is missing (%s); reinstall the mod",
      tostring(readErr or "unknown read error"))
    return
  end

  local chunk, compileErr = load(source, "@" .. mod.path .. "/screen.lua")
  if not chunk then
    mod.log:error("screen.lua did not compile: %s", tostring(compileErr))
    return
  end

  local okFactory, factory = pcall(chunk)
  if not okFactory or type(factory) ~= "function" then
    mod.log:error("screen.lua must return a factory function: %s",
      tostring(factory))
    return
  end

  local okScreen, screen = pcall(factory, mod, genderExports, compatibility,
    effectiveMenuPalette, useStockOgMenuPalette, effectivePaperPalette,
    rawMenuPaletteCopy)
  if not okScreen or type(screen) ~= "table"
      or type(screen.new) ~= "function" then
    mod.log:error("PC screen factory failed: %s", tostring(screen))
    return
  end

  local originalBoxMenu = mod.content.screens:get("BoxMenu")
  local boxMenuWrapper = {
    new = function(game, ...)
      if activeMod and activeMod.options:get("modern_pc_ui") == true then
        return screen.new(game, ...)
      end
      if originalBoxMenu and type(originalBoxMenu.new) == "function" then
        return originalBoxMenu.new(game, ...)
      end
      return BoxMenu.new(game, ...)
    end
  }

  if originalBoxMenu then
    mod.content.screens:override("BoxMenu", boxMenuWrapper)
  else
    mod.content.screens:register("BoxMenu", boxMenuWrapper)
  end

  local originalPartyMenu = mod.content.screens:get("PartyMenu")
  local partyMenuWrapper = {
    new = function(game, ...)
      return PartyMenu.new(game, ...)
    end
  }
  if originalPartyMenu then
    mod.content.screens:override("PartyMenu", partyMenuWrapper)
  else
    mod.content.screens:register("PartyMenu", partyMenuWrapper)
  end

  local originalSummaryMenu = mod.content.screens:get("SummaryMenu")
  local summaryMenuWrapper = {
    new = function(game, ...)
      return SummaryMenu.new(game, ...)
    end
  }
  if originalSummaryMenu then
    mod.content.screens:override("SummaryMenu", summaryMenuWrapper)
  else
    mod.content.screens:register("SummaryMenu", summaryMenuWrapper)
  end

  -- Modern Bag UI is vendored under BetterMenus-owned filenames. Preserve
  -- the controller registered before us so the option can switch presentation
  -- off without changing item behavior or requiring a restart.
  local function loadBagFactory(filename)
    local bagSource, bagReadErr = mod:read(filename)
    if not bagSource then
      mod.log:error("%s is missing (%s); Modern Bag UI disabled", filename,
        tostring(bagReadErr or "unknown read error"))
      return nil
    end
    local bagChunk, bagCompileErr = load(
      bagSource, "@" .. mod.path .. "/" .. filename)
    if not bagChunk then
      mod.log:error("%s did not compile: %s", filename,
        tostring(bagCompileErr))
      return nil
    end
    local okBagFactory, bagFactory = pcall(bagChunk)
    if not okBagFactory or type(bagFactory) ~= "function" then
      mod.log:error("%s must return a factory function", filename)
      return nil
    end
    return bagFactory
  end

  local makeBagScreen = loadBagFactory("modern_bag_screen.lua")
  local makeBagInventory = loadBagFactory("modern_bag_inventory.lua")
  if makeBagScreen and makeBagInventory then
    local originalBagScreen = mod.content.screens:get("BagMenu")
    local bagCompatibility = {
      usefulBag = mod.find("useful_bag") ~= nil,
      kantoReforged = mod.find("Kanto-Reforged") ~= nil,
      upstreamBagScreen = mod.find("Kanto-Reforged") and originalBagScreen
        or nil,
    }
    local okBagScreen, modernBagScreen = pcall(
      makeBagScreen, mod, bagCompatibility, effectiveMenuPalette,
      useStockOgMenuPalette, effectivePaperPalette, rawMenuPaletteCopy)
    local okBagInventory, modernBagInventory = false, nil
    if okBagScreen and type(modernBagScreen) == "table"
        and type(modernBagScreen.new) == "function" then
      okBagInventory, modernBagInventory = pcall(
        makeBagInventory, mod, modernBagScreen, bagCompatibility)
    end
    if okBagScreen and okBagInventory and type(modernBagInventory) == "table" then
      local bagMenuWrapper = {
        new = function(game, ...)
          if activeMod.options:get("modern_bag_ui") ~= false then
            return modernBagScreen.new(game, ...)
          end
          if originalBagScreen and type(originalBagScreen.new) == "function" then
            return originalBagScreen.new(game, ...)
          end
          return BagMenu.new(game, ...)
        end,
      }
      if originalBagScreen then
        mod.content.screens:override("BagMenu", bagMenuWrapper)
      else
        mod.content.screens:register("BagMenu", bagMenuWrapper)
      end
      mod.exports.modernBag = modernBagScreen
      mod.exports.modernBagInventoryLimits = modernBagInventory.limits
    else
      mod.log:error("Modern Bag UI factory failed: %s / %s",
        tostring(modernBagScreen), tostring(modernBagInventory))
    end
  end
  
    local hudSource, hudReadErr = mod:read("hud.lua")
	  if not hudSource then
		mod.log:error("hud.lua is missing (%s); reinstall the mod",
		  tostring(hudReadErr or "unknown read error"))
		return
	  end

	  local hudChunk, hudCompileErr = load(
		hudSource,
		"@" .. mod.path .. "/hud.lua"
	  )

	  if not hudChunk then
		mod.log:error("hud.lua did not compile: %s",
		  tostring(hudCompileErr))
		return
	  end

	  local hudOk, installHud = pcall(hudChunk)
	  if not hudOk or type(installHud) ~= "function" then
		mod.log:error("hud.lua must return an installer: %s",
		  tostring(installHud))
		return
	  end

	  local installedHud, hudInstallErr = pcall(installHud, mod,
		effectiveMenuPalette, useStockOgMenuPalette, modernBattleUIMode)
	  if not installedHud then
		mod.log:error("battle information HUD failed: %s",
		  tostring(hudInstallErr))
		return
	  end
  
  local frameGame
  local nicknameBackdrop

	local function visibleTitle(game)
	  local top = game and game.stack and game.stack:top()
	  local states = game and game.stack and game.stack.states or {}

	  for i = 1, #states do
		local title = states[i]

	if getmetatable(title) == TitleState
	   and (
		 top == title
		 or getmetatable(top) == OptionsMenu
		 or (top and
		   (top.enhancedTitleMenu or top.enhancedTitleInfo))
	   ) then
		  return title
		end
	  end

	  return false
	end

  mod.options:define({
    { key = "palette", label = "MENU PALETTE", type = "choice",
      default = "soulsilver",
      choices = {
	    { "GAME BOY", "gameboy" },
		{ "BLACK AND WHITE", "blackwhite" },
		{ "OG RED", "ogred" },
		{ "ADVANCED", "redpp" },
		{ "SGB", "gbc" },
        { "SOULSILVER", "soulsilver" },
        { "HEARTGOLD", "heartgold" },
        { "FIRERED", "firered" },
        { "LEAFGREEN", "leafgreen" },
        { "CRYSTAL", "crystal" },
        { "EMERALD", "emerald" },
		{ "AMIGA WB", "amiga_wb" },
		{ "AMIGA DP", "amiga_dp" },
		{ "C64", "c64" },
		{ "SPECTRUM", "spectrum" },
		{ "CGA", "cga" },
		{ "APPLE2", "apple2" },
		{ "POCKET", "pocket" },
		{ "GB LIGHT", "gblight" },
		{ "VIRTUAL BOY", "virtualboy" },
		{ "AMBER", "amber" },
		{ "PHOSPHOR", "phosphor" },
		{ "PLASMA", "plasma" },
		{ "RAINBOW", "rainbow" },
		{ "ACID", "acid" },
		{ "FUSCHIA", "fuchsia" },
		{ "SUNSET", "sunset" },
		{ "OCEAN", "ocean" },
		{ "FOREST", "forest" },
		{ "LAVA", "lava" },
		{ "ICE", "ice" },
		{ "CANDY", "candy" },
		{ "VAPOR", "vapor" },
		{ "NEON", "neon" },
		{ "TOXIC", "toxic" },
		{ "SEPIA", "sepia" },
		{ "NOIR", "noir" },
		{ "CHERRY", "cherry" },
		{ "MIDNIGHT", "midnight" },
		{ "GOLD", "gold" },
		{ "MINT", "mint" },
		{ "GRAPE", "grape" },
      } },
    { key = "inverse", label = "Inverse", type = "toggle",
      default = false },
    { key = "modern_pc_ui", label = "Modern PC UI", type = "toggle",
      default = false },
    { key = "modern_bag_ui", label = "Modern Bag UI", type = "toggle",
      default = true },
    { key = "modern_battle_ui", label = "Modern Battle UI", type = "choice",
      default = "on",
      choices = {
        { "OFF", "off" },
        { "ON", "on" },
        { "MOD", "mod" },
      } },
    { key = "marquee_text", label = "Marquee Text", type = "toggle",
      default = true },
    { key = "pokedex_indicator", label = "Pokédex Indicator", type = "choice",
      default = "default",
      choices = {
        { "OFF", "off" },
        { "DEFAULT", "default" },
        { "RED", "red" },
      } },
  })
  
  local defaultMenuPalettes = {
    { "GAME BOY", "gameboy" },
    { "BLACK AND WHITE", "blackwhite" },
    { "OG RED", "ogred" },
    { "ADVANCED", "redpp" },
    { "SGB", "gbc" },
  }
  local betterMenusPalettes = {
    { "SOULSILVER", "soulsilver" },
    { "HEARTGOLD", "heartgold" },
    { "FIRERED", "firered" },
    { "LEAFGREEN", "leafgreen" },
    { "CRYSTAL", "crystal" },
    { "EMERALD", "emerald" },
  }
  local groovyMenuPalettes = {
    { "AMIGA WB", "amiga_wb" }, { "AMIGA DP", "amiga_dp" },
    { "C64", "c64" }, { "SPECTRUM", "spectrum" },
    { "CGA", "cga" }, { "APPLE2", "apple2" },
    { "POCKET", "pocket" }, { "GB LIGHT", "gblight" },
    { "VIRTUAL BOY", "virtualboy" }, { "AMBER", "amber" },
    { "PHOSPHOR", "phosphor" }, { "PLASMA", "plasma" },
    { "RAINBOW", "rainbow" }, { "ACID", "acid" },
    { "FUSCHIA", "fuchsia" }, { "SUNSET", "sunset" },
    { "OCEAN", "ocean" }, { "FOREST", "forest" },
    { "LAVA", "lava" }, { "ICE", "ice" },
    { "CANDY", "candy" }, { "VAPOR", "vapor" },
    { "NEON", "neon" }, { "TOXIC", "toxic" },
    { "SEPIA", "sepia" }, { "NOIR", "noir" },
    { "CHERRY", "cherry" }, { "MIDNIGHT", "midnight" },
    { "GOLD", "gold" }, { "MINT", "mint" },
    { "GRAPE", "grape" },
  }

  local function setOption(game, key, value)
    local manager = ManagerState.new(game)
    manager:setOption("gen1-better-menus", key, value)
  end

  local COMPACT_VISIBLE = 13

  local function compactState(game, title, rows, onClose, wide, fixed, onStart)
    local selectable = {}
    for i, row in ipairs(rows) do
      if row.selectable ~= false then selectable[#selectable + 1] = i end
    end
    local state = {
      game = game, title = title, rows = rows,
      selection = 1, scroll = 0,
      isOpaque = false, holdsUIAnchors = true,
    }

    local function geometry()
      local canvasTw = UI_TW
      local maxTw = wide and (UI_TW - 2) or 20
      local maxLabel = title and Font.width(Strings(title)) or 0
      local visible = math.min(COMPACT_VISIBLE, #rows - state.scroll)
      local widthFirst = fixed and 1 or (state.scroll + 1)
      local widthLast = fixed and #rows or (state.scroll + visible)
      for rowIndex = widthFirst, widthLast do
        local row = rows[rowIndex]
        if row and row.label then
          local rowWidth = Font.width(Strings(row.label))
          if wide and row.value then
            local valueWidth = Font.width(Strings(row.value(game)))
            for _, value in ipairs(row.widthValues or {}) do
              valueWidth = math.max(valueWidth, Font.width(Strings(value)))
            end
            rowWidth = rowWidth + 8 + valueWidth
          end
          maxLabel = math.max(maxLabel, rowWidth)
        end
      end
      local tw = math.max(8, math.min(maxTw, math.ceil((maxLabel + 24) / 8)))
      local lineCount = title and 1 or 0
      local layouts = {}
      for slot = 1, visible do
        local row = rows[state.scroll + slot]
        local lines = 1
        if row and row.value then
          local label = Strings(row.label or "")
          local value = Strings(row.value(game))
          local valueWidth = Font.width(value)
          if fixed then
            for _, candidate in ipairs(row.widthValues or {}) do
              valueWidth = math.max(valueWidth, Font.width(Strings(candidate)))
            end
          end
          local valueX = (tw - 1) * 8 - valueWidth
          if 16 + Font.width(label) + 8 > valueX then lines = 2 end
        end
        layouts[slot] = lines
        lineCount = lineCount + lines
      end
      local th = math.min(18, lineCount + 2)
      return math.floor((canvasTw - tw) / 2), math.floor((18 - th) / 2),
        tw, th, visible, layouts
    end

    function state:uiSize() return UI_W, UI_H end
    function state:frameGeometry() return geometry() end
    function state:sgbPalettes()
      local tx, ty, tw, th = geometry()
      return { PaletteFX.zone(effectiveMenuPalette(game), tx, ty,
        tx + tw - 1, ty + th - 1) }
    end
    function state:draw()
      local tx, ty, tw, th, visible, layouts = geometry()
      local ox, oy = tx * 8, ty * 8
      Font.drawBox(tx, ty, tw, th)
      love.graphics.setColor(0, 0, 0, 1)
      local line = 1
      if title then
        Font.draw(Strings(title), ox + 16, oy + 8)
        line = 2
      end
      local selectedRow = selectable[self.selection]
      for slot = 1, visible do
        local i = self.scroll + slot
        local row = rows[i]
        if not row then break end
        local y = oy + line * 8
        if row.separator then
          love.graphics.rectangle("fill", ox + 8, y + 3,
            (tw - 2) * 8, 1)
        elseif row.heading then
          Font.draw(Strings(row.label), ox + 8, y)
        else
          local label = Strings(row.label)
          Font.draw(label, ox + 16, y)
          if row.value then
            local value = Strings(row.value(game))
            if layouts[slot] == 2 then
              Font.draw(value, ox + 24, y + 8)
            else
              Font.draw(value,
                ox + (tw - 1) * 8 - Font.width(value), y)
            end
          end
          if i == selectedRow then Font.drawCode(Theme.cursor, ox + 8, y) end
        end
        line = line + layouts[slot]
      end
      love.graphics.setColor(1, 1, 1, 1)
    end
    local function clamp()
      local rowIndex = selectable[state.selection]
      if rowIndex <= state.scroll then state.scroll = rowIndex - 1
      elseif rowIndex > state.scroll + COMPACT_VISIBLE then
        state.scroll = rowIndex - COMPACT_VISIBLE
      end
      state.scroll = math.max(0,
        math.min(state.scroll, math.max(0, #rows - COMPACT_VISIBLE)))
    end
    function state:update()
      local input = game.input
      if input:wasPressed("up") then
        self.selection = self.selection > 1 and self.selection - 1 or #selectable
      elseif input:wasPressed("down") then
        self.selection = self.selection < #selectable and self.selection + 1 or 1
      elseif input:wasPressed("left") then
        local row = rows[selectable[self.selection]]
        if row and row.step then row.step(game, -1) end
      elseif input:wasPressed("right") then
        local row = rows[selectable[self.selection]]
        if row and row.step then row.step(game, 1) end
      elseif input:wasPressed("start") and onStart then
        onStart(game)
        return
      elseif input:wasPressed("a") then
        local row = rows[selectable[self.selection]]
        if row then
          if row.activate then row.activate(game)
          elseif row.describe then row.describe(game) end
        end
      elseif input:wasPressed("b") then
        game.stack:pop()
        if onClose then onClose() end
        return
      end
      clamp()
    end
    clamp()
    return state
  end

  local function transitionToChild(game, parent, child)
    parent.gen1BetterMenusOpeningChild = true
    if game.stack:top() == parent then game.stack:pop() end

    local childUpdate = child.update
    child.update = function(self, ...)
      childUpdate(self, ...)
      if self.gen1BetterMenusOpeningChild then
        self.gen1BetterMenusOpeningChild = nil
        return
      end
      if game.stack:top() ~= self
          and not self.gen1BetterMenusReturnedToParent then
        self.gen1BetterMenusReturnedToParent = true
        game.stack:push(parent)
      end
    end
    game.stack:push(child)
  end

  local function upstreamLiveBrowser(game, entries, kind)
    local openedPalette = game.save.options.palette or ""
    local openedMode = game.save.options.colors or "gbc"
    local model = PaletteScreen.new(game)
    local index = 1
    local opened = kind == "mode" and openedMode or openedPalette
    for i, entry in ipairs(entries) do
      if entry.id == opened then index = i break end
    end

    local browser = {
      game = game,
      isOpaque = false,
      holdsUIAnchors = true,
      gen1BetterMenusSuppressLocationBanner = true,
      index = index,
    }

    local function apply(entry)
      if kind == "mode" then
        model.set("")
        model.setMode(entry.id)
      else
        model.set(entry.id)
      end
    end

    local function restore()
      if openedPalette ~= "" then
        model.setMode(openedMode)
        model.set(openedPalette)
      else
        model.set("")
        model.setMode(openedMode)
      end
    end

    apply(entries[index])

    local function popupGeometry()
      local label = PaletteScreen.sanitize(entries[browser.index].label)
      local tiles = math.min(20, math.ceil(Font.width(label) / 8) + 2)
      return label, math.floor((UI_TW - tiles) / 2), tiles
    end

    function browser:uiSize() return UI_W, UI_H end
    function browser:sgbPalettes()
      local _, tx, tiles = popupGeometry()
      return { PaletteFX.zone(PaletteFX.pal(game.data, "MEWMON"),
        tx, 0, tx + tiles - 1, 2) }
    end
    function browser:update()
      local input = game.input
      local n = #entries
      if input:wasPressed("left") or input:wasPressed("up") then
        self.index = self.index > 1 and self.index - 1 or n
        apply(entries[self.index])
      elseif input:wasPressed("right") or input:wasPressed("down") then
        self.index = self.index < n and self.index + 1 or 1
        apply(entries[self.index])
      elseif input:wasPressed("a") or input:wasPressed("start") then
        game.stack:pop()
      elseif input:wasPressed("b") then
        restore()
        game.stack:pop()
      end
    end
    function browser:draw()
      local label, tx, tiles = popupGeometry()
      Font.drawBox(tx, 0, tiles, 3)
      love.graphics.setColor(0, 0, 0, 1)
      Font.draw(label, (tx + 1) * 8, 8)
      love.graphics.setColor(1, 1, 1, 1)
    end
    return browser
  end

  local function upstreamCategoryEntries(key)
    local Palette = require("src.render.Palette")
    if key == "mono" then
      local entries = {}
      for _, color in ipairs(Palette.MONO_COLOURS or {}) do
        entries[#entries + 1] = {
          label = color[1],
          id = Palette.monoId(color[2], color[3], color[4]),
        }
      end
      return entries, "palette"
    elseif key == "og" then
      local entries = {}
      local wanted = { "ogred", "gbc", "redpp", "og",
        "og_inv", "gbc_inv", "classic" }
      for _, id in ipairs(wanted) do
        entries[#entries + 1] = {
          label = PaletteFX.modeLabel(id), id = id,
        }
      end
      return entries, "mode"
    end

    local category = Palette.category(key)
    local entries = {}
    for _, entry in ipairs(category and category.palettes or {}) do
      entries[#entries + 1] = { label = entry.name, id = entry.id }
    end
    return entries, "palette"
  end

  local function defaultPaletteState(game)
    local rows = {}
    local groups = {
      { "FULL COLOR", "full" },
      { "SINGLE COLOR", "single" },
      { "GREYSCALE", "grey" },
      { "MONOCHROME", "mono" },
      { "OG", "og" },
    }
    for _, group in ipairs(groups) do
      local label, key = group[1], group[2]
      rows[#rows + 1] = {
        label = label,
        activate = function(g)
          local entries, kind = upstreamCategoryEntries(key)
          if #entries > 0 then
            local parent = g.stack:top()
            transitionToChild(g, parent,
              upstreamLiveBrowser(g, entries, kind))
          end
        end,
      }
    end
    return compactState(game, nil, rows)
  end

  local function menuPaletteBrowser(game, parent, choices)
    local openedPalette = activeMod.options:get("palette")
    local index = 1
    for i, choice in ipairs(choices) do
      if choice[2] == openedPalette then index = i break end
    end

    local browser = {
      game = game,
      isOpaque = false,
      holdsUIAnchors = true,
      index = index,
    }

    local function apply()
      setOption(game, "palette", choices[browser.index][2])
    end

    apply()

    function browser:uiSize() return UI_W, UI_H end
    function browser:sgbPalettes()
      local ptx, pty, ptw = parent:frameGeometry()
      local label = Strings(choices[self.index][1])
      local tw = math.min(ptw, math.max(8,
        math.ceil((Font.width(label) + 16) / 8)))
      local tx = ptx + math.floor((ptw - tw) / 2)
      local ty = math.max(0, pty - 3)
      local zones = parent:sgbPalettes() or {}
      zones[#zones + 1] = PaletteFX.zone(effectiveMenuPalette(game),
        tx, ty, tx + tw - 1, ty + 2)
      return zones
    end
    function browser:update()
      local input = game.input
      local n = #choices
      if input:wasPressed("left") or input:wasPressed("up") then
        self.index = self.index > 1 and self.index - 1 or n
        apply()
      elseif input:wasPressed("right") or input:wasPressed("down") then
        self.index = self.index < n and self.index + 1 or 1
        apply()
      elseif input:wasPressed("a") or input:wasPressed("start") then
        game.stack:pop()
      elseif input:wasPressed("b") then
        setOption(game, "palette", openedPalette)
        game.stack:pop()
      end
    end
    function browser:draw()
      parent:draw()
      local ptx, pty, ptw = parent:frameGeometry()
      local label = Strings(choices[self.index][1])
      local tw = math.min(ptw, math.max(8,
        math.ceil((Font.width(label) + 16) / 8)))
      local tx = ptx + math.floor((ptw - tw) / 2)
      local ty = math.max(0, pty - 3)
      Font.drawBox(tx, ty, tw, 3)
      love.graphics.setColor(0, 0, 0, 1)
      Font.draw(label, (tx + 1) * 8, (ty + 1) * 8)
      love.graphics.setColor(1, 1, 1, 1)
    end
    return browser
  end

  local function groovyAvailable()
    return mod.find("groovy_palette") ~= nil
  end

  local function groovyGameEntries()
    local available = {}
    for _, id in ipairs(PaletteFX.MODES or {}) do available[id] = true end
    local entries = {}
    for _, choice in ipairs(groovyMenuPalettes) do
      local id = choice[2]
      if available[id] then
        entries[#entries + 1] = {
          label = PaletteFX.MODE_LABELS[id] or choice[1],
          id = id,
        }
      end
    end
    return entries
  end

  local function descriptionState(game, parent, text)
    local pages = TextBox.paginate(Strings(text), 30)
    local lines = pages[1] or {}
    local state = {
      game = game, isOpaque = false, holdsUIAnchors = true,
    }
    local tw, th = 34, 8
    local tx, ty = math.floor((UI_TW - tw) / 2), math.floor((UI_TH - th) / 2)
    function state:uiSize() return UI_W, UI_H end
    function state:sgbPalettes()
      local zones = parent:sgbPalettes() or {}
      zones[#zones + 1] = PaletteFX.zone(effectiveMenuPalette(game),
        tx, ty, tx + tw - 1, ty + th - 1)
      return zones
    end
    function state:draw()
      parent:draw()
      Font.drawBox(tx, ty, tw, th)
      love.graphics.setColor(0, 0, 0, 1)
      for i = 1, math.min(#lines, th - 2) do
        Font.draw(lines[i], (tx + 1) * 8, (ty + i) * 8)
      end
      love.graphics.setColor(1, 1, 1, 1)
    end
    function state:update()
      local input = game.input
      if input:wasPressed("a") or input:wasPressed("b")
          or input:wasPressed("start") then
        game.stack:pop()
      end
    end
    return state
  end

  local function betterMenusState(game, reopenStart)
    local rows = {}
    local function addGroup(label, choices)
      rows[#rows + 1] = {
        label = label,
        activate = function(g)
          local parent = g.stack:top()
          g.stack:push(menuPaletteBrowser(g, parent, choices))
        end,
      }
    end
    if groovyAvailable() then addGroup("Groovy", groovyMenuPalettes) end
    addGroup("Default", defaultMenuPalettes)
    addGroup("BetterMenus", betterMenusPalettes)
    rows[#rows + 1] = { selectable = false, separator = true }
    rows[#rows + 1] = {
      label = "Inverse",
      value = function() return activeMod.options:get("inverse") and "ON" or "OFF" end,
      widthValues = { "ON", "OFF" },
      step = function(g) setOption(g, "inverse", not activeMod.options:get("inverse")) end,
      description = "Invert your color palette",
    }
    rows[#rows + 1] = {
      label = "Modern PC UI",
      value = function() return activeMod.options:get("modern_pc_ui") and "ON" or "OFF" end,
      widthValues = { "ON", "OFF" },
      step = function(g) setOption(g, "modern_pc_ui", not activeMod.options:get("modern_pc_ui")) end,
    }
    rows[#rows + 1] = {
      label = "Modern Bag UI",
      value = function() return activeMod.options:get("modern_bag_ui") ~= false and "ON" or "OFF" end,
      widthValues = { "ON", "OFF" },
      step = function(g) setOption(g, "modern_bag_ui", not (activeMod.options:get("modern_bag_ui") ~= false)) end,
    }
    rows[#rows + 1] = {
      label = "Modern Battle UI",
      value = function() return modernBattleUIMode():upper() end,
      widthValues = { "ON", "OFF", "MOD" },
      step = function(g)
        local mode = modernBattleUIMode()
        mode = mode == "on" and "off" or mode == "off" and "mod" or "on"
        setOption(g, "modern_battle_ui", mode)
      end,
      description = function()
        local mode = modernBattleUIMode()
        if mode == "on" then
          return "This will add an XP bar to the user Pokémon panel and a Pokédex 'Caught' indicator to the enemy Pokémon panel"
        elseif mode == "off" then
          return "BetterMenus will provide palette coverage for stock drawn Battle UI"
        end
        return "Use this option if you want to use a custom Battle UI or you see issues with your preferred mod using the OFF setting"
      end,
    }
    rows[#rows + 1] = {
      label = "Marquee Text",
      value = function() return activeMod.options:get("marquee_text") ~= false and "ON" or "OFF" end,
      widthValues = { "ON", "OFF" },
      step = function(g) setOption(g, "marquee_text", not (activeMod.options:get("marquee_text") ~= false)) end,
      description = "Use this to disable scrolling text in the menus if you prefer",
    }
    rows[#rows + 1] = {
      label = "Pokédex Indicator",
      value = function()
        local value = activeMod.options:get("pokedex_indicator")
        if value == "off" then return "OFF" end
        return value == "red" and "RED" or "DEFAULT"
      end,
      widthValues = { "OFF", "DEFAULT", "RED" },
      step = function(g)
        local value = activeMod.options:get("pokedex_indicator")
        setOption(g, "pokedex_indicator", value == "off" and "default"
          or value == "default" and "red" or "off")
      end,
      description = function()
        return activeMod.options:get("pokedex_indicator") == "default"
          and "The Poké Ball follows the menu palette theme" or nil
      end,
    }
    local state
    for _, row in ipairs(rows) do
      if row.description then
        local describedRow = row
        describedRow.describe = function(g)
          local text
          if type(describedRow.description) == "function" then
            text = describedRow.description(g)
          else
            text = describedRow.description
          end
          if text then g.stack:push(descriptionState(g, state, text)) end
        end
      end
    end
    state = compactState(game, nil, rows, nil, true, true, function(g)
      if g.stack:top() == state then g.stack:pop() end
      local top = g.stack:top()
      if top and top.gen1BetterMenusColorsMenu then g.stack:pop() end
      if reopenStart then reopenStart() end
    end)
    return state
  end

  local function colorsState(game, reopenStart)
    local rows = {}
    if groovyAvailable() then
      rows[#rows + 1] = {
        label = "GROOVY",
        activate = function(g)
          local parent = g.stack:top()
          local entries = groovyGameEntries()
          if #entries > 0 then
            transitionToChild(g, parent,
              upstreamLiveBrowser(g, entries, "mode"))
          end
        end,
      }
    end
    rows[#rows + 1] = {
      label = "DEFAULT",
      activate = function(g)
        local parent = g.stack:top()
        transitionToChild(g, parent, defaultPaletteState(g))
      end,
    }
    rows[#rows + 1] = { selectable = false, separator = true }
    rows[#rows + 1] = {
      label = "BetterMenus",
      activate = function(g) g.stack:push(betterMenusState(g, reopenStart)) end,
    }
    local state = compactState(game, nil, rows, reopenStart)
    state.gen1BetterMenusColorsMenu = true
    return state
  end

  mod.hooks:wrap("ui.start_menu.items", function(next, game, items)
    items = next(game, items)

    if groovyAvailable() then
      for i = #items, 1, -1 do
        if tostring(items[i].label) == "PALETTE" then table.remove(items, i) end
      end
    end

    -- Change QUIT to close the application, then add RESTART below it.
    for i, item in ipairs(items) do
      if tostring(item.label) == "QUIT" then
        item.onSelect = function()
          local TextBox = require("src.render.TextBox")

          game.stack:push(TextBox.new(
            game,
            Strings("QUIT THE GAME?"),
            nil,
            {
              defaultNo = true,
              choice = function(yes)
                if yes then
                  pcall(love.filesystem.write, "relaunch_to_launcher.txt", "1")
                  require("src.core.HostShell").restart()
                end
              end,
            }
          ))
        end

        table.insert(items, i + 1, {
          label = Strings("RESTART"),
          onSelect = function()
            local TextBox = require("src.render.TextBox")

            game.stack:push(TextBox.new(
              game,
              Strings("RETURN TO MAIN\nMENU?"),
              nil,
              {
                defaultNo = true,
                choice = function(yes)
                  if yes then
                    game:returnToTitle()
                  end
                end,
              }
            ))
          end,
        })

        break
      end
    end

    local insertAt = #items + 1
    for i, item in ipairs(items) do
      if tostring(item.label) == "QUIT" then insertAt = i break end
    end
    table.insert(items, insertAt, {
      label = Strings("COLORS"),
      onSelect = function()
        game.stack:push(colorsState(game, function()
          Screens.push(game, "StartMenu")
        end))
      end,
    })

	  return items
	end, 7)

  installModOptionsMarkerCompatibility()
  installOptionsLayout()
  installOverworldScaleStability()
  installListLayout()
  installMenuLayout()
  installBattlePaletteIsolation()
  installDialogueLayout()
  installSupportingScreens()
  installManagerLayout()
  installLinkLayout()
  installReportLayout()
  installLocationBanners(mod)
  mod.hooks:wrap("screen.render_visible", function(next, state)
    local visible = next(state)

    if getmetatable(state) == PokedexMenu then
      local top = frameGame and frameGame.stack and frameGame.stack:top()
      if top and getmetatable(top) == DexEntryMenu then
        return false
      end
    end

    return visible
  end)
  mod.hooks:wrap("render.compose", function(next, renderer, ctx)
    local handled = next(renderer, ctx)
    local solidNickname = false
    local game = frameGame
    for _, state in ipairs(game and game.stack and game.stack.states or {}) do
      if state and state.gen1BetterMenusSolidNickname then
        solidNickname = true
        break
      end
    end
    if solidNickname and ctx and ctx.ww and ctx.wh then
      if not nicknameBackdrop
         or nicknameBackdrop:getWidth() ~= ctx.ww
         or nicknameBackdrop:getHeight() ~= ctx.wh then
        nicknameBackdrop = love.graphics.newCanvas(ctx.ww, ctx.wh)
      end
      local previous = love.graphics.getCanvas()
      love.graphics.setCanvas(nicknameBackdrop)
      love.graphics.clear(PaletteFX.paperShade(game.data))
      love.graphics.setCanvas(previous)
      love.graphics.setColor(1, 1, 1, 1)
      renderer:setWorldOverride(nicknameBackdrop)
    end
    return handled
  end)
  mod.hooks:wrap("battle.overlay", function(next, battle)
    next(battle)
    if not modernBattleUIEnabled() then return end
    if not (battle and battle.wideLayout and battle:wideLayout()
            and battle.extendedHUD and battle:extendedHUD()) then return end
    local g = love.graphics
    local r, green, b, a = g.getColor()
    local blend, alpha = g.getBlendMode()
    g.setBlendMode("replace")
    g.setColor(0, 0, 0, 0)
    g.rectangle("fill", 75, 121, 2, 1)
    g.rectangle("fill", 227, 121, 2, 1)
    g.setBlendMode(blend, alpha)
    g.setColor(r, green, b, a)
  end)
  mod.hooks:wrap("render.letterbox", function(next, ctx)
    next(ctx)
    local top = frameGame and frameGame.stack and frameGame.stack:top()
    if top and top.__modernBagFrameBackdrop
       and ctx and ctx.ww and ctx.wh then
      local r, green, b, a = love.graphics.getColor()
      love.graphics.setColor(PaletteFX.paperShade(frameGame.data))
      love.graphics.rectangle("fill", 0, 0, ctx.ww, ctx.wh)
      love.graphics.setColor(r, green, b, a)
      return
    end
    if top and top.modernBagUI and ctx and ctx.ww and ctx.wh then
      local palette = PaletteFX.effectiveColors(effectiveMenuPalette())
      local footer = palette and palette[3] or { 85, 85, 85 }
      local r, green, b, a = love.graphics.getColor()
      love.graphics.setColor(
        footer[1] / 255, footer[2] / 255, footer[3] / 255, 1)
      love.graphics.rectangle("fill", 0, 0, ctx.ww, ctx.wh)
      love.graphics.setColor(r, green, b, a)
      return
    end
    local introNaming = false
    for _, state in ipairs(frameGame and frameGame.stack
        and frameGame.stack.states or {}) do
      if state and state.gen1BetterMenusIntroNaming then
        introNaming = true
        break
      end
    end
    if introNaming and ctx and ctx.ww and ctx.wh then
      local palette = PaletteFX.effectiveColors(effectiveMenuPalette())
      local paper = palette and palette[1] or { 255, 255, 255 }
      local r, green, b, a = love.graphics.getColor()
      love.graphics.setColor(
        paper[1] / 255, paper[2] / 255, paper[3] / 255, 1)
      love.graphics.rectangle("fill", 0, 0, ctx.ww, ctx.wh)
      love.graphics.setColor(r, green, b, a)
      return
    end
    local title = visibleTitle(frameGame)
    if not (title and ctx and ctx.ww and ctx.wh) then
      return
    end
   local top = frameGame and frameGame.stack and frameGame.stack:top()
local paper

if top and top ~= title then
  local menuColors = PaletteFX.effectiveColors(effectiveMenuPalette())
  paper = menuColors and menuColors[1] or { 255, 255, 255 }
else
  local sourceColors = YELLOW_TITLE_PIKACHU

  if not title.yellowLayout then
    local zones = title:sgbPalettes(frameGame)
    sourceColors = zones and zones[1] and zones[1].colors or sourceColors
  end

  local titleColors = PaletteFX.effectiveColors(sourceColors)
  paper = titleColors and titleColors[1] or { 255, 255, 255 }
end
    local r, green, b, a = love.graphics.getColor()
    love.graphics.setColor(
      paper[1] / 255, paper[2] / 255, paper[3] / 255, 1)
    love.graphics.rectangle("fill", 0, 0, ctx.ww, ctx.wh)
    love.graphics.setColor(r, green, b, a)
  end)
  mod.hooks:wrap("render.hud", function(next, game, viewport)
    next(game, viewport)
    local top = game and game.stack and game.stack:top()
    local options = game and game.save and game.save.options

    -- Summary sprites are transparent images. Draw them after the menu's
    -- palette pass so true-color art is never remapped and no rectangular
    -- true-color zone can expose an unpaletted seam around the sprite.
    if top and getmetatable(top) == SummaryMenu and top.sprite
        and viewport and viewport.gameX and viewport.gameY
        and viewport.gameWidth and viewport.gameHeight then
      local pw, ph = top.sprite:getDimensions()
      local py = math.max(0, 56 - ph)
      local scaleX = viewport.gameWidth / UI_W
      local scaleY = viewport.gameHeight / UI_H
      local r, green, b, a = love.graphics.getColor()
      local previousShader = love.graphics.getShader()
      local scissorX, scissorY, scissorW, scissorH = love.graphics.getScissor()
      local monPal = top.mon
        and PaletteFX.monPal(game.data, top.mon.species)
      local shader = not top.spriteTrueColor
        and monPal and PaletteFX.shader()

      love.graphics.push()
      love.graphics.setScissor(
        viewport.gameX, viewport.gameY,
        viewport.gameWidth, viewport.gameHeight)
      love.graphics.translate(viewport.gameX, viewport.gameY)
      love.graphics.scale(scaleX, scaleY)
      love.graphics.setColor(1, 1, 1, 1)
      if shader then
        PaletteFX.sendColors(shader, monPal)
        love.graphics.setShader(shader)
      else
        love.graphics.setShader()
      end
      love.graphics.draw(top.sprite, 8 + pw, py, 0, -1, 1)
      love.graphics.pop()

      love.graphics.setShader(previousShader)
      if scissorX then
        love.graphics.setScissor(scissorX, scissorY, scissorW, scissorH)
      else
        love.graphics.setScissor()
      end
      love.graphics.setColor(r, green, b, a)
    end

    -- The responsive Bag reaches the logical canvas edge, but the final
    -- presentation pass can leave one framebuffer row from the overworld.
    -- Cover that post-composite seam with the active menu footer color.
    local states = game and game.stack and game.stack.states or {}
    local stack = game and game.stack
    local first = stack and stack.visibleBase and stack:visibleBase() or 1
    local modernBagVisible = false
    for i = first, #states do
      if states[i] and states[i].modernBagUI then
        modernBagVisible = true
        break
      end
    end
    if modernBagVisible and viewport and viewport.width and viewport.height then
      local palette = PaletteFX.effectiveColors(effectiveMenuPalette())
      local footer = palette and palette[3] or { 85, 85, 85 }
      local pixelH = 1 / (viewport.dpiY or 1)
      local r, green, b, a = love.graphics.getColor()
      love.graphics.setColor(
        footer[1] / 255, footer[2] / 255, footer[3] / 255, 1)
      love.graphics.rectangle(
        "fill", 0, viewport.height - pixelH, viewport.width, pixelH)
      love.graphics.setColor(r, green, b, a)
    end

	local pipelineId = Pipelines.worldPipeline()
    if not (modernBattleUIEnabled()
            and top and getmetatable(top) == BattleState
            and top.extendedHUD and top:extendedHUD()
            and top.wantsFillScale and top:wantsFillScale()
            and options and options.battleBg == "white"
			and not pipelineId
            and viewport and viewport.gameY and viewport.gameY > 0) then
      return
    end
    local scale = math.min(viewport.height / UI_H, viewport.width / UI_W)
    local uiX = math.floor((viewport.width - UI_W * scale) / 2)
    local uiY = math.floor((viewport.height - UI_H * scale) / 2)
    local x = math.floor(uiX + 128 * scale)
    local r, green, b, a = love.graphics.getColor()
    love.graphics.setColor(PaletteFX.paperShade(game.data))
    love.graphics.rectangle("fill", x, 0, viewport.width - x, uiY)
    love.graphics.setColor(r, green, b, a)
  end)
  mod.hooks:wrap("render.zones", function(next, game, zones)
    frameGame = game
    activeGame = game
    local out = next(game, zones) or {}
    local top = game and game.stack and game.stack:top()
    local mt = top and getmetatable(top)

    -- Modern Bag composes a responsive pixel-space surface and supplies its
    -- complete palette map through its own sgbPalettes method.  Appending the
    -- legacy tile-space Menu/ListMenu zones below recolors the old 160px Bag
    -- region over that surface, producing the vertical palette stripe.  Once
    -- Modern Bag owns the visible palette map, leave it unchanged here.
    local states = game and game.stack and game.stack.states or {}
    local stack = game and game.stack
    local first = stack and stack.visibleBase and stack:visibleBase() or 1
    for i = first, #states do
      if states[i] and states[i].modernBagUI then
        return out
      end
    end

    if mt == BattleState and top.wideLayout and top:wideLayout() then
      local battleMode = modernBattleUIMode()
      if battleMode ~= "mod" then
        out[#out + 1] = battleUIZone(effectiveMenuPalette(), 0, 0, 15, 3)
        out[#out + 1] = battleUIZone(effectiveMenuPalette(), 23, 7, 37, 12)
        out[#out + 1] = battleUIZone(effectiveMenuPalette(), 0, 13, 37, 17)
        -- Standard WIDE draws its bottom message/command panels directly on
        -- the main battle canvas.  The detached-HUD zone above is isolated
        -- from that canvas, so add the same exact 104..143 panel band as a
        -- main-canvas zone in ON/OFF. MOD remains the complete opt-out.
        if not (top.extendedHUD and top:extendedHUD()) then
          out[#out + 1] = PaletteFX.zone(
            effectiveMenuPalette(), 0, 13, 37, 17)
        end
      end
      if battleMode == "off" then
        out[#out + 1] = {
          colors = false, x = 8, y = 16, w = 112, h = 8,
          gen1BetterMenusBattleUI = true,
        }
        out[#out + 1] = {
          colors = false, x = 192, y = 72, w = 112, h = 8,
          gen1BetterMenusBattleUI = true,
        }
      end
      -- ON preserves only semantic meter fills. OFF restores each complete
      -- stock HP element (label, track, and fill) after palette treatment.
    else
      local title
      for i = 1, #states do
        if getmetatable(states[i]) == TitleState then
          title = states[i]
          break
        end
      end
      -- Color every visible UI overlay, not only the top state. A ChoiceBox
      -- sits above its TextBox, and ContinueInfo is private to TitleState;
      -- walking the visible stack covers both without depending on names.
      for i = first, #states do
        local state = states[i]
        local stateMt = state and getmetatable(state)
        if stateMt == Menu then
          out[#out + 1] = PaletteFX.zone(effectiveMenuPalette(), state.tx, state.ty,
            state.tx + state.tw - 1, state.ty + state.th - 1)
          if state.gen1BetterMenusPCChrome then
            out[#out + 1] = PaletteFX.zone(
              effectiveMenuPalette(), 0, 12, UI_TW - 1, UI_TH - 1)
          end
        elseif state and state.isTextBox then
          out[#out + 1] = PaletteFX.zone(effectiveMenuPalette(), state.boxTx, state.boxTy,
            state.boxTx + state.boxTw - 1,
            state.boxTy + state.boxTh - 1)
        elseif stateMt == ChoiceBox then
          out[#out + 1] = PaletteFX.zone(effectiveMenuPalette(), state.tx, state.ty,
            state.tx + state.tw - 1, state.ty + state.th - 1)
        elseif stateMt == TrainerCard then
          out[#out + 1] = PaletteFX.zone(effectiveMenuPalette(), 0, 0, UI_TW - 1, UI_TH - 1)
        elseif stateMt == QuarantineReport then
          out[#out + 1] = PaletteFX.zone(effectiveMenuPalette(), 0, 0, 19, 17)
        elseif state and state.titleUiBox then
          local box = state.titleUiBox
          out[#out + 1] = PaletteFX.zone(effectiveMenuPalette(),
            box[1], box[2], box[3], box[4])
        end
      end

      local locationVisible = updateLocationBanner(game)
      if locationVisible and states[first] == game.overworld then
        out[#out + 1] = PaletteFX.zone(effectiveMenuPalette(), 0, 14, 19, 17)
      end
    end
    return out
  end)
end

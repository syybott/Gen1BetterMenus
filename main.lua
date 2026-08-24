-- Gen1BetterMenus 1.0.21

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
local ListMenu = require("src.ui.ListMenu")
local Menu = require("src.ui.Menu")
local BoxMenu = require("src.ui.BoxMenu")
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
local Runtime = require("src.mods.Runtime")
local Bag = require("src.inventory.Bag")

local UI_W, UI_H = 304, 144
local UI_TW, UI_TH = UI_W / 8, UI_H / 8
local TITLE_PANEL_TW = 13
local TITLE_INFO_TH = 10

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
local LOCATION_OVERLAY_KEY = "__qolLocationBannerOverlay"
local locationStates = setmetatable({}, { __mode = "k" })
local locationOverlays = setmetatable({}, { __mode = "k" })

local function colors()
  local id = activeMod and activeMod.options:get("palette") or "soulsilver"
  local palette = PALETTES[id] or PALETTES.soulsilver
  if activeMod and activeMod.options:get("inverse") then
    return { palette[4], palette[3], palette[2], palette[1] }
  end
  return palette
end

local function wholeWide()
  return { PaletteFX.zone(colors(), 0, 0, UI_TW - 1, UI_TH - 1) }
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
	local sid = top and type(top.screenId) == "string"
  and top.screenId:lower() or ""

local dynamicOptionRows =
  top
  and type(top.rows) == "function"
  and type(top.index) == "number"
  and type(top.scroll) == "number"

if isOptionRowsScreen(top) or dynamicOptionRows then
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
    return { PaletteFX.zone(colors(), 0, 0, UI_TW - 1, UI_TH - 1) }
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
    Font.drawCode(B.v, tx * 8, (ty + j) * 8)
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
    self.update = function(list, dt)
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

  ListMenu.draw = function(self)
    local states = self.game and self.game.stack and self.game.stack.states or {}

    for i = 1, #states - 1 do
      if states[i] == self
          and getmetatable(states[i + 1]) == DexEntryMenu then
        return
      end
    end
    sortBagFavorites(self)
    drawOuterFrame(self.title)
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
          and favoriteItems(self.game.save)[item.value] then
        drawFavoriteHeart(labelX + Font.width(item.label) + 4, y)
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
      opts.tx, opts.tw = 0, UI_TW
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
	  opts.tx = UI_TW - opts.tw
	  opts.ty = 0
	  opts.itemY = 1
	  opts.th = 17
      opts.anchor = "topright"
    end
    local self = originalNew(game, items, opts)
	if opts.startCloses then
	  self.tw = 11
	end
	parent = game and game.stack and game.stack:top()
	if parent and getmetatable(parent) == ListMenu
      and not self.anchor then
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
      if not centerPCMenu and not self.anchor
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
    originalUpdate(self, dt)
    if titleMenu then patchContinueInfo(self) end
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
        PaletteFX.zone(colors(), 0, 0, UI_TW - 1, UI_TH - 1),
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

    originalMenuDraw(self)

    for i, item in ipairs(self.items) do
      item.label = originalLabels[i]
    end

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
  Font.drawBox(0, 15, 20, 3)
  love.graphics.setColor(0, 0, 0, 1)
  local width = Font.width(state.name)
  Font.draw(state.name, math.max(8, math.floor((160 - width) / 2)), 128)
  love.graphics.setColor(1, 1, 1, 1)
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
  end)
end

local function updateLocationBanner(game)
  local world = game and game.overworld
  local overlay = world and rawget(world, LOCATION_OVERLAY_KEY)
  if overlay and not locationOverlays[overlay] then
    locationOverlays[overlay] = overlay.draw
    overlay.draw = function()
      local state = locationStates[world]
      if state and love.timer.getTime() < state.expiresAt then
        drawLocationBanner(world)
      elseif locationOverlays[overlay] then
        locationOverlays[overlay](world)
      end
    end
  end
  local state = world and locationStates[world]
  return state and love.timer.getTime() < state.expiresAt
end

local function installDialogueLayout()
  local originalNew = TextBox.new
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
    -- The SAVE panel waits 30 frames before creating its TextBox. Widen it
    -- as it enters the stack so the retained START menu never flashes first.
    widenSavePanel(Game, state)
    return originalPush(stack, state, ...)
  end

  TextBox.new = function(game, text, onDone, opts)
    local self = originalNew(game, text, onDone, opts)
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
        local base = colors()
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

	  local offset = math.floor((UI_W - Renderer.WIDTH) / 2)

	  return {
	  -- Base Pokédex palette across the wide surface.
	  PaletteFX.zone(base, 0, 0, UI_TW - 1, UI_TH - 1),

	  -- Pokémon sprite palette.
	  PaletteFX.zone(
		PaletteFX.monPal(game.data, self.def and self.def.id),
		offset / 8 + 1,
		1,
		offset / 8 + 8,
		8
	  ),

	  -- Active menu palette on the Pokédex frame only.
	  PaletteFX.zone(colors(), 9, 0, 28, 0),    -- top
	  PaletteFX.zone(colors(), 9, 17, 28, 17),  -- bottom
	  PaletteFX.zone(colors(), 9, 0, 9, 17),    -- left
	  PaletteFX.zone(colors(), 28, 0, 28, 17),  -- right
	  PaletteFX.zone(colors(), 9, 9, 28, 9),    -- middle divider
	}
	end

	DexEntryMenu.uiSize = function()
	  return UI_W, UI_H
	end

	DexEntryMenu.isWideBattleLayout = function()
	  return false
	end

	DexEntryMenu.isOpaque = false
	
	local originalDexEntryDraw = DexEntryMenu.draw

	DexEntryMenu.draw = function(self)
	  local sx, sy, sw, sh = love.graphics.getScissor()

	  -- The Dex renderer still inherits the classic 160px clip.
	  -- Remove it while drawing the centered page.
	  love.graphics.setScissor()

	  love.graphics.push()
	  love.graphics.translate((UI_W - Renderer.WIDTH) / 2, 0)
	  originalDexEntryDraw(self)
	  love.graphics.pop()

	  if sx then
		love.graphics.setScissor(sx, sy, sw, sh)
	  end
	end

  -- The classic trainer card is a panel over the field. Keeping the world in
  -- the visible stack replaces its black outer frame with the overworld.
  TrainerCard.isOpaque = false
  TrainerCard.sgbPalettes = wholeWide

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
    if wideBattle then
      local originalDraw = self.draw
      self.gen1BetterMenusSolidNickname = true
      self.uiSize = function() return UI_W, UI_H end
      self.isWideBattleLayout = function() return true end
      self.sgbPalettes = function(_, currentGame)
        local base = colors()
        local palette = { base[1], base[2], base[3], base[4] }
        local r, g, b = PaletteFX.paperShade(currentGame.data)
        palette[1] = {
          math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5),
          math.floor(b * 255 + 0.5),
        }
        return { PaletteFX.zone(palette, 0, 0, UI_TW - 1, UI_TH - 1) }
      end
      self.draw = function(screen)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.rectangle("fill", 0, 0, UI_W, UI_H)
        love.graphics.push()
        love.graphics.translate(math.floor((UI_W - Renderer.WIDTH) / 2), 0)
        originalDraw(screen)
        love.graphics.pop()
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
    return 8 + col * 144, 8 + row * 40
  end

  makeWideState(PartyMenu)
  PartyMenu.sgbPalettes = function(self, game)
    local zones = wholeWide()
    if not self.tmhm then
      local party = self.party or (game.save and game.save.party) or {}
      for i, mon in ipairs(party) do
        local x, y = partySlot(i)
        local hp = mon.hp
        if self.heal and self.heal.mon == mon then hp = self.heal.from end
        local bar = PaletteFX.pal(game.data,
          PaletteFX.barPalName(hp, mon.stats.hp))
        if bar then
		zones[#zones + 1] = {
		  colors = bar,
		  x = x + 5 * 8,
		  y = y + 19,
		  w = 4 * 8,
		  h = 2,
		}
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
    if #party == 0 then Font.draw(Strings("No POKéMON!"), 16, 64) end

    for i, mon in ipairs(party) do
      local x, y = partySlot(i)
      local def = self.game.data.pokemon[mon.species]
      love.graphics.setColor(1, 1, 1, 1)
      PartyMenu.drawIcon(self.game, mon, x + 8, y,
                         i == self.index, self.blink or 0)
      love.graphics.setColor(0, 0, 0, 1)
      Font.draw(truncate(mon.nickname or def.name, 10), x + 24, y)
      if mon.level < 100 then
        HudTiles.tile(0x6E, x + 112, y)
        Font.draw(tostring(mon.level), x + 120, y)
      else
        Font.draw(tostring(mon.level), x + 112, y)
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
    local flat = {}
    for _, page in ipairs(TextBox.paginate(self:bottomMessage(), 34)) do
      for _, line in ipairs(page) do flat[#flat + 1] = line end
    end
    local y = #flat > 1 and 112 or 128
    for i = math.max(1, #flat - 1), #flat do
      Font.draw(flat[i], 16, y)
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
        self.isWideBattleLayout = function() return false end
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
  originalSummaryDraw(self)

  if self.sprite then
    local pw, ph = self.sprite:getDimensions()
    local py = math.max(0, 56 - ph)

	local palette = PaletteFX.effectiveColors(colors())
	local paper = palette and palette[1]

	if paper then
	  love.graphics.setColor(
		paper[1] / 255,
		paper[2] / 255,
		paper[3] / 255,
		1
	  )

	  love.graphics.rectangle("fill", 8, py, pw, ph)

	  love.graphics.setColor(1, 1, 1, 1)
	  love.graphics.draw(self.sprite, 8 + pw, py, 0, -1, 1)

	  if self.spriteTrueColor then
		PaletteFX.markTrueColor(8, py, pw, ph)
	  end
	end
  end
end
  
  makeWideState(SummaryMenu)
  SummaryMenu.sgbPalettes = wholeWide
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

  local okScreen, screen = pcall(factory, mod, genderExports, compatibility)
  if not okScreen or type(screen) ~= "table"
      or type(screen.new) ~= "function" then
    mod.log:error("PC screen factory failed: %s", tostring(screen))
    return
  end

  if mod.content.screens:get("BoxMenu") then
    mod.content.screens:override("BoxMenu", screen)
  else
    mod.content.screens:register("BoxMenu", screen)
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

	  local installedHud, hudInstallErr = pcall(installHud, mod, colors)
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
        { "SOULSILVER", "soulsilver" },
        { "HEARTGOLD", "heartgold" },
        { "FIRERED", "firered" },
        { "LEAFGREEN", "leafgreen" },
        { "CRYSTAL", "crystal" },
        { "EMERALD", "emerald" },
		{ "1", "amiga_wb" },
		{ "2", "amiga_dp" },
		{ "3", "c64" },
		{ "4", "spectrum" },
		{ "5", "cga" },
		{ "6", "apple2" },
		{ "7", "pocket" },
		{ "8", "gblight" },
		{ "9", "virtualboy" },
		{ "10", "amber" },
		{ "11", "phosphor" },
		{ "12", "plasma" },
		{ "13", "rainbow" },
		{ "14", "acid" },
		{ "15", "fuchsia" },
		{ "16", "sunset" },
		{ "17", "ocean" },
		{ "18", "forest" },
		{ "19", "lava" },
		{ "20", "ice" },
		{ "21", "candy" },
		{ "22", "vapor" },
		{ "23", "neon" },
		{ "24", "toxic" },
		{ "25", "sepia" },
		{ "26", "noir" },
		{ "27", "cherry" },
		{ "28", "midnight" },
		{ "29", "gold" },
		{ "30", "mint" },
		{ "31", "grape" },
      } },
    { key = "inverse", label = "INVERSE", type = "toggle",
      default = false },
  })
  
    mod.hooks:wrap("ui.start_menu.items", function(next, game, items)
    items = next(game, items)

    local insertAt = #items + 1

    for i, item in ipairs(items) do
      if tostring(item.label) == "SAVE" then
        insertAt = i
        break
      end
    end

    table.insert(items, insertAt, {
      label = Strings("MENU PALETTE"),
      onSelect = function()
  
local paletteChoices = {
	  "gameboy",
	  "blackwhite",
	  "soulsilver",
	  "heartgold",
	  "firered",
	  "leafgreen",
	  "crystal",
	  "emerald",
	  "ogred",
	  "ogredobj",
	  "ogblue",
	  "amiga_wb",
	  "amiga_dp",
	  "c64",
	  "spectrum",
	  "cga",
	  "apple2",
	  "pocket",
	  "gblight",
	  "virtualboy",
	  "amber",
	  "phosphor",
	  "plasma",
	  "rainbow",
	  "acid",
	  "fuchsia",
	  "sunset",
	  "ocean",
	  "forest",
	  "lava",
	  "ice",
	  "candy",
	  "vapor",
	  "neon",
	  "toxic",
	  "sepia",
	  "noir",
	  "cherry",
	  "midnight",
	  "gold",
	  "mint",
	  "grape",
	}

	local function setOption(key, value)
	  local manager = ManagerState.new(game)
	  manager:setOption("gen1-better-menus", key, value)
	end

	local paletteState = {
	  game = game,
	  index = 1,
	  scroll = 0,
	  isOpaque = false,
	}

	local rows = {
	  {
		label = "MENU PALETTE",
		value = function()
		  local current = activeMod.options:get("palette")

		  for i, id in ipairs(paletteChoices) do
			if id == current then
			  return tostring(i)
			end
		  end

		  return "1"
		end,
		step = function(_, dir)
		  local current = activeMod.options:get("palette")
		  local index = 1

		  for i, id in ipairs(paletteChoices) do
			if id == current then
			  index = i
			  break
			end
		  end

		  index = index + dir

		  if index < 1 then
			index = #paletteChoices
		  elseif index > #paletteChoices then
			index = 1
		  end

		  setOption("palette", paletteChoices[index])
		  return true
		end,
	  },

	  {
		label = "INVERSE",
		value = function()
		  return activeMod.options:get("inverse") and "ON" or "OFF"
		end,
		step = function()
		  setOption("inverse", not activeMod.options:get("inverse"))
		  return true
		end,
	  },
	}

	function paletteState:uiSize()
	  return UI_W, UI_H
	end

	function paletteState:sgbPalettes()
	  return wholeWide()
	end

	function paletteState:draw()
	  OptionRows.draw(game, rows, self.index, self.scroll, "B:DONE")
	end

	function paletteState:update()
	  local input = game.input

	  if input:wasPressed("up") then
		self.index = self.index > 1 and self.index - 1 or #rows

	  elseif input:wasPressed("down") then
		self.index = self.index < #rows and self.index + 1 or 1

	  elseif input:wasPressed("left") then
		rows[self.index].step(game, -1)

	  elseif input:wasPressed("right") then
		rows[self.index].step(game, 1)

	  elseif input:wasPressed("a") then
		rows[self.index].step(game, 1)

	  elseif input:wasPressed("b") then
		game.stack:pop()
		Screens.push(game, "StartMenu")
	  end

	  self.scroll = OptionRows.clampScroll(
		self.index,
		self.scroll,
		#rows
	  )
	end

	game.stack:push(paletteState)
		end,
	  })

	  return items
	end)

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
    local introNaming = false
    for _, state in ipairs(frameGame and frameGame.stack
        and frameGame.stack.states or {}) do
      if state and state.gen1BetterMenusIntroNaming then
        introNaming = true
        break
      end
    end
    if introNaming and ctx and ctx.ww and ctx.wh then
      local palette = PaletteFX.effectiveColors(colors())
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
  local menuColors = PaletteFX.effectiveColors(colors())
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

	local pipelineId = Pipelines.worldPipeline()
    if not (top and getmetatable(top) == BattleState
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
    local out = next(game, zones) or {}
    local top = game and game.stack and game.stack:top()
    local mt = top and getmetatable(top)

    if mt == BattleState and top.wideLayout and top:wideLayout() then
      -- Wide battle draws true-colour arena and Pokémon, so recolour only
      -- the three opaque UI panels rather than the completed battle canvas.
      out[#out + 1] = battleUIZone(colors(), 0, 0, 15, 3)
      out[#out + 1] = battleUIZone(colors(), 23, 7, 37, 11)
      out[#out + 1] = battleUIZone(colors(), 0, 13, 37, 17)
      -- The HP bars retain their semantic green/yellow/red colors.
      out[#out + 1] = battleUIZone(false, 1, 2, 14, 2)
      out[#out + 1] = battleUIZone(false, 24, 9, 36, 9)
    else
      local title
      local states = game and game.stack and game.stack.states or {}
      for i = 1, #states do
        if getmetatable(states[i]) == TitleState then
          title = states[i]
          break
        end
      end
      -- Color every visible UI overlay, not only the top state. A ChoiceBox
      -- sits above its TextBox, and ContinueInfo is private to TitleState;
      -- walking the visible stack covers both without depending on names.
      local stack = game and game.stack
      local first = stack and stack.visibleBase and stack:visibleBase() or 1
      for i = first, #states do
        local state = states[i]
        local stateMt = state and getmetatable(state)
        if stateMt == Menu then
          out[#out + 1] = PaletteFX.zone(colors(), state.tx, state.ty,
            state.tx + state.tw - 1, state.ty + state.th - 1)
          if state.gen1BetterMenusPCChrome then
            out[#out + 1] = PaletteFX.zone(
              colors(), 0, 12, UI_TW - 1, UI_TH - 1)
          end
        elseif state and state.isTextBox then
          out[#out + 1] = PaletteFX.zone(colors(), state.boxTx, state.boxTy,
            state.boxTx + state.boxTw - 1,
            state.boxTy + state.boxTh - 1)
        elseif stateMt == ChoiceBox then
          out[#out + 1] = PaletteFX.zone(colors(), state.tx, state.ty,
            state.tx + state.tw - 1, state.ty + state.th - 1)
        elseif stateMt == TrainerCard then
          out[#out + 1] = PaletteFX.zone(colors(), 0, 0, UI_TW - 1, UI_TH - 1)
        elseif stateMt == QuarantineReport then
          out[#out + 1] = PaletteFX.zone(colors(), 0, 0, 19, 17)
        elseif state and state.titleUiBox then
          local box = state.titleUiBox
          out[#out + 1] = PaletteFX.zone(colors(),
            box[1], box[2], box[3], box[4])
        end
      end

      local locationVisible = updateLocationBanner(game)
      if locationVisible and states[first] == game.overworld then
        out[#out + 1] = PaletteFX.zone(colors(), 0, 15, 19, 17)
      end
    end
    return out
  end)
end

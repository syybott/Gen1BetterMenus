-- Gen1 Better Menus 0.1.0

local Font = require("src.render.Font")
local PaletteFX = require("src.render.PaletteFX")
local Theme = require("src.ui.Theme")
local Strings = require("src.core.Strings")

local OptionRows = require("src.ui.OptionRows")
local OptionsMenu = require("src.ui.OptionsMenu")
local ListMenu = require("src.ui.ListMenu")
local Menu = require("src.ui.Menu")
local PokedexMenu = require("src.ui.PokedexMenu")
local PartyMenu = require("src.ui.PartyMenu")
local SummaryMenu = require("src.ui.SummaryMenu")
local TextBox = require("src.render.TextBox")
local ChoiceBox = require("src.ui.ChoiceBox")
local ManagerState = require("src.mods.ManagerState")
local LinkState = require("src.link.LinkState")
local BattleState = require("src.battle.BattleState")
local QuarantineReport = require("src.ui.QuarantineReport")
local TitleState = require("src.ui.TitleState")
local Runtime = require("src.mods.Runtime")

local UI_W, UI_H = 304, 144
local UI_TW, UI_TH = UI_W / 8, UI_H / 8

local PALETTES = {
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
  -- Prevent Game.lua from centering this already-wide state when it is
  -- opened over the native 304px battle composition.
  class.isWideBattleLayout = function() return true end
  -- These menus are panels over the field. Keeping them non-opaque lets the
  -- normal world pass replace the black letterbox around the wide panel.
  class.isOpaque = false
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

local function installReportLayout()
  QuarantineReport.sgbPalettes = function()
    return { PaletteFX.zone(colors(), 0, 0, 19, 17) }
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
  OptionsMenu.sgbPalettes = wholeWide
  -- ManagerState uses OptionRows for each mod's settings page. Without the
  -- same canvas declaration the compact 38-tile renderer would be clipped
  -- back to the manager's original 20-tile surface.
  makeWideState(ManagerState)
  ManagerState.sgbPalettes = wholeWide
end

local function installListLayout()
  makeWideState(ListMenu)
  ListMenu.sgbPalettes = wholeWide
  -- PokedexMenu stamps its own palette function onto the ListMenu instance,
  -- so update that factory-owned function as well as the generic class.
  PokedexMenu.sgbPalettes = wholeWide

  ListMenu.draw = function(self)
    drawOuterFrame(self.title)
    if #self.items == 0 then
      Font.draw(Strings("Nothing here."), 24, 64)
    end
    for row = 1, self.rows do
      local i = self.scroll + row
      local item = self.items[i]
      if not item then break end
      local y = 8 + row * 16
      Font.draw(item.label, 24, y)
      if item.ball then
        local bx, by = 24 + Font.width(item.label) + 11, y + 3
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

  local function colorizeYellowPikachu(game, source)
    local logo = PaletteFX.effectiveColors(PaletteFX.pal(game.data, "LOGO2"))
    local pika = PaletteFX.effectiveColors(PaletteFX.pal(game.data, "MEWMON"))
    if not (logo and pika) then return nil end
    if type(source) == "table" then source = source.path end
    source = source or "assets/generated/title/pikachu.png"
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
    local tw, th = menu.tw, menu.th
    info.titleUiBox = { 0, 0, tw - 1, th - 1 }
    info.uiSize = function() return UI_W, UI_H end
    info.isWideBattleLayout = function() return true end
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
      Font.drawBox(0, 0, tw, th)
      love.graphics.setColor(0, 0, 0, 1)
      for i, row in ipairs(rows) do
        Font.draw(truncate(row, inner), 8, i * 8)
      end
      love.graphics.setColor(1, 1, 1, 1)
    end
  end

  Menu.new = function(game, items, opts)
    opts = opts or {}
    local titleMenu = game and game.stack
      and getmetatable(game.stack:top()) == TitleState
    if titleMenu then
      opts.tx, opts.ty, opts.tw = 0, 0, 13
      opts.rowStep, opts.th = 1, #items + 2
    end
    if opts.startCloses then
      opts.tx, opts.ty, opts.tw = 20, 0, 18
      opts.anchor = "topright"
    end
    local self = originalNew(game, items, opts)
    self.enhancedTitleMenu = titleMenu
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
    originalTitleDraw(self)
    if self.enhancedYellowPikachu then
      local w, h = self.yellowPikachu:getDimensions()
      PaletteFX.markTrueColor(32, 64 - (self.scy or 0), w, h)
    end
  end

  Menu.uiSize = function() return UI_W, UI_H end
  Menu.isWideBattleLayout = function() return true end
  Menu.isOpaque = false
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
  TextBox.new = function(game, text, onDone, opts)
    local self = originalNew(game, text, onDone, opts)
    self.boxTx, self.boxTy, self.boxTw, self.boxTh = 0, 13, UI_TW, 5
    self.maxCols = 36
    self.textX, self.line1Y, self.line2Y = 8, 112, 128
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
            colors = bar, x = x + 3 * 8, y = y + 16,
            w = 7 * 8, h = 8,
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
      Font.draw(truncate(mon.nickname or def.name, 9), x + 32, y)
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
      drawCut(self.notice, 16, 15 * 8, 34)
      return
    end
    if line1 then drawCut(line1, 16, 15 * 8, 34) end
    if line2 then drawCut(line2, 16, 16 * 8, 34) end
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
    for i, row in ipairs(rows) do
      drawCut(row.label, 32, (10 + i) * 8, 32)
      if i == self.cursor then Font.drawCode(Theme.cursor, 24, (10 + i) * 8) end
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

return function(mod)
  activeMod = mod
  mod.options:define({
    { key = "palette", label = "MENU PALETTE", type = "choice",
      default = "soulsilver",
      choices = {
        { "SOULSILVER", "soulsilver" },
        { "HEARTGOLD", "heartgold" },
        { "FIRERED", "firered" },
        { "LEAFGREEN", "leafgreen" },
        { "CRYSTAL", "crystal" },
        { "EMERALD", "emerald" },
      } },
    { key = "inverse", label = "INVERSE", type = "toggle",
      default = false },
  })

  installOptionsLayout()
  installListLayout()
  installMenuLayout()
  installDialogueLayout()
  installSupportingScreens()
  installManagerLayout()
  installLinkLayout()
  installReportLayout()
  installLocationBanners(mod)
  mod.hooks:wrap("render.zones", function(next, game, zones)
    local out = next(game, zones) or {}
    local top = game and game.stack and game.stack:top()
    local mt = top and getmetatable(top)

    if mt == BattleState and top.wideLayout and top:wideLayout() then
      -- Wide battle draws true-colour arena and Pokémon, so recolour only
      -- the three opaque UI panels rather than the completed battle canvas.
      out[#out + 1] = PaletteFX.zone(colors(), 0, 0, 15, 3)
      out[#out + 1] = PaletteFX.zone(colors(), 23, 7, 37, 11)
      out[#out + 1] = PaletteFX.zone(colors(), 0, 13, 37, 17)
      -- The HP bars retain their semantic green/yellow/red colors.
      out[#out + 1] = PaletteFX.zone(false, 1, 2, 14, 2)
      out[#out + 1] = PaletteFX.zone(false, 24, 9, 36, 9)
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
        elseif state and state.isTextBox then
          out[#out + 1] = PaletteFX.zone(colors(), state.boxTx, state.boxTy,
            state.boxTx + state.boxTw - 1,
            state.boxTy + state.boxTh - 1)
        elseif stateMt == ChoiceBox then
          out[#out + 1] = PaletteFX.zone(colors(), state.tx, state.ty,
            state.tx + state.tw - 1, state.ty + state.th - 1)
        elseif stateMt == QuarantineReport then
          out[#out + 1] = PaletteFX.zone(colors(), 0, 0, 19, 17)
        elseif state and state.titleUiBox then
          local box = state.titleUiBox
          out[#out + 1] = PaletteFX.zone(colors(),
            box[1], box[2], box[3], box[4])
        end
      end

      if updateLocationBanner(game) then
        out[#out + 1] = PaletteFX.zone(colors(), 0, 15, 19, 17)
      end
    end
    return out
  end)
end

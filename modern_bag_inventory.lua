-- Expanded storage for the modern Bag.  The engine already stores inventory
-- as item-id dictionaries, so native saves do not need a migration; only the
-- cartridge-era validation limits and quantity box width need to change.

local SLOT_MAX = 255
local STACK_MAX = 999

return function(mod, bagScreen, compatibility)
  compatibility = compatibility or {}
  local Bag = require("src.inventory.Bag")
  local Font = require("src.render.Font")
  local PlayerPC = require("src.ui.PlayerPC")
  local QuantityBox = require("src.ui.QuantityBox")
  local Strings = require("src.core.Strings")

  local function stackCount(store)
    local count = 0
    for _ in pairs(store or {}) do count = count + 1 end
    return count
  end

  local function sortedIds(_, store)
    local ids = {}
    for id in pairs(store or {}) do ids[#ids + 1] = id end
    table.sort(ids)
    return ids
  end

  -- Respect a larger capacity installed before this mod instead of reducing
  -- it. Kanto Reforged deliberately owns a 60-slot pocket system, so keep its
  -- limit rather than replacing that controller contract with our 255 slots.
  local currentSlots = tonumber(mod.content.constants:get("bagSize")) or 20
  local activeSlots = compatibility.kantoReforged
    and currentSlots or math.max(currentSlots, SLOT_MAX)
  if activeSlots ~= currentSlots then
    mod.content.constants:patch("bagSize", activeSlots)
  end

  -- Bag.add is the engine's single acquisition/withdrawal guard.  Keep its
  -- original behavior through 99, then extend the same slot/order rules up
  -- to the configured stack maximum.  Module tags make dev hot reload safe.
  Bag.__modernBagStackMax = math.max(
    tonumber(Bag.__modernBagStackMax) or 99, STACK_MAX)
  if not Bag.__modernBagStackLimitPatched then
    Bag.__modernBagStackLimitPatched = true
    Bag.__modernBagOriginalAdd = Bag.add
    Bag.add = function(save, id, qty, data)
      -- If a previously loaded inventory mod already accepts this addition,
      -- retain its behavior (including any limit higher than ours).
      if Bag.__modernBagOriginalAdd(save, id, qty, data) then return true end

      local amount = qty or 1
      local inv = save.inventory
      local total = (inv[id] or 0) + amount

      if Bag.isBadge(id) or total <= 99 then return false end
      if total > Bag.__modernBagStackMax then return false end
      if not inv[id] and Bag.slots(save) >= Bag.capacity(data) then
        return false
      end

      local isNew = not inv[id]
      local order = isNew and Bag.order(save) or nil
      inv[id] = total
      if isNew then table.insert(order, id) end
      return true
    end
  end

  -- A three-digit quantity needs one extra tile.  This also covers PC
  -- withdraw/toss selectors for any existing expanded stack.
  if not QuantityBox.__modernBagWideQuantityPatched then
    QuantityBox.__modernBagWideQuantityPatched = true
    QuantityBox.__modernBagOriginalNew = QuantityBox.new
    QuantityBox.new = function(game, opts)
      opts = opts or {}
      local adjusted = {}
      for key, value in pairs(opts) do adjusted[key] = value end

      local depositId = game.__modernBagPCDepositId
      if depositId then
        local pc = game.save.pcItems or {}
        local remaining = math.max(0,
          Bag.__modernBagStackMax - (pc[depositId] or 0))
        adjusted.max = math.min(adjusted.max or remaining, remaining)
      end

      local box = QuantityBox.__modernBagOriginalNew(game, adjusted)
      if box.max >= 100 and not box.unitPrice then
        box.draw = function(self)
          local tx, ty = 14, 9
          Font.drawBox(tx, ty, 6, 3)
          love.graphics.setColor(0, 0, 0, 1)
          Font.draw(("×%03d"):format(self.qty),
            (tx + 1) * 8, (ty + 1) * 8)
          love.graphics.setColor(1, 1, 1, 1)
        end
      end
      return box
    end
  end

  -- PC item capacity is not yet a public content constant.  Delegate to the
  -- complete native PlayerPC screen, raising its existing field limit and
  -- constraining deposits so a stored stack cannot pass x999.
  local playerPC = {
    new = function(game)
      game.data.field = game.data.field or {}
      game.data.field.pcItemCap = math.max(
        tonumber(game.data.field.pcItemCap) or 50, activeSlots)

      local menu = PlayerPC.new(game)
      local function constrainDeposit(list)
        local chooseDeposit = list.onChoose
        list.onChoose = function(item, activeList)
          local pc = game.save.pcItems or {}
          if (pc[item.value] or 0) >= Bag.__modernBagStackMax then
            activeList.footer = Strings("No room left to\nstore items.")
            return
          end

          game.__modernBagPCDepositId = item.value
          local ok, chosen = pcall(chooseDeposit, item, activeList)
          game.__modernBagPCDepositId = nil
          if not ok then error(chosen, 0) end
          return chosen
        end
      end

      local actions = {
        {
          index = 1, label = "WITHDRAW ITEM", short = "WITHDRAW",
          direction = "PC TO BAG", modePalette = "GREENMON",
          empty = { "PC STORAGE", "IS EMPTY" },
          emptyName = "WITHDRAW",
          blurb = "Stored PC items move into your Bag.",
          store = function() return game.save.pcItems or {} end,
          detailStatus = function() return Strings("STORED") end,
        },
        {
          index = 2, label = "DEPOSIT ITEM", short = "DEPOSIT",
          direction = "BAG TO PC", modePalette = "YELLOWMON",
          empty = { "NO STORABLE", "BAG ITEMS" },
          emptyName = "DEPOSIT",
          blurb = "Carried items move from your Bag into the PC.",
          store = function() return game.save.inventory or {} end,
          filter = function(_, id) return not Bag.isBadge(id) end,
          detailStatus = function() return Strings("CARRIED") end,
          deposit = true,
        },
        {
          index = 3, label = "TOSS ITEM", short = "TOSS",
          direction = "PC TO TRASH", modePalette = "REDMON",
          empty = { "NO STORED ITEMS", "TO TOSS" },
          emptyName = "TOSS",
          blurb = "Stored PC items selected here will be thrown away.",
          store = function() return game.save.pcItems or {} end,
          detailStatus = function() return Strings("STORED") end,
        },
      }

      for _, action in ipairs(actions) do
        local row = menu.items and menu.items[action.index]
        if row and type(row.onSelect) == "function" then
          local openList = row.onSelect
          row.onSelect = function()
            local previousTop = game.stack:top()
            local result = openList()
            local list = game.stack:top()
            if list == previousTop or not list
                or type(list.onChoose) ~= "function" then
              return result
            end

            if action.deposit then constrainDeposit(list) end
            if bagScreen and type(bagScreen.decorateList) == "function" then
              bagScreen.decorateList(list, {
                header = "PC",
                label = action.label,
                short = action.short,
                store = action.store,
                order = sortedIds,
                filter = action.filter,
                capacity = function()
                  return ("%d/%d"):format(
                    stackCount(game.save.pcItems),
                    game.data.field.pcItemCap)
                end,
                detailStatus = action.detailStatus,
                direction = action.direction,
                modePalette = action.modePalette,
                empty = action.empty,
                emptyName = action.emptyName,
                blurb = action.blurb,
              })
            end
            return result
          end
        end
      end
      return menu
    end,
  }

  return {
    playerPC = playerPC,
    limits = { slots = activeSlots, stack = Bag.__modernBagStackMax },
  }
end


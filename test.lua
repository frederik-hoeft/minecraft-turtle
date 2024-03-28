BRIDGE_BLOCK_SLOT = 1
TORCH_SLOT = 2
INVENTORY_SLOT_COUNT = 16
WORKING_SLOT = 16

BridgeBlockItem = nil
TorchItem = nil

SlotState = { Item = nil, Count = 0 }

function SlotState:create(o)
  o.parent = self
  return o
end

Slots = {}
ValuableItems = {}
PreferredItems = {}

-- returns true if the provided item is of interest
function isValuableItem(item)
  return ValuableItems[item] ~= nil
end

function isPreferredItem(item)
  return PreferredItems[item] ~= nil
end

-- register items of interest, determine item types for bridge building and torches
function setupInventory()
  for i = 1, INVENTORY_SLOT_COUNT do
    local slotState = nil
    local currentCount = turtle.getItemCount(i)
    if (currentCount > 0) then
      slotState = SlotState:create({Item = turtle.getItemDetail(i).name, Count = currentCount})
      ValuableItems[slotState.Item] = true
      PreferredItems[slotState.Item] = true
      if (i == BRIDGE_BLOCK_SLOT) then
        WriteLine("Bridge block item found: " .. slotState.Item)
        BridgeBlockItem = slotState.Item
        ValuableItems[slotState.Item] = nil
      end
      if (i == TORCH_SLOT) then
        WriteLine("Torch item found: " .. slotState.Item)
        TorchItem = slotState.Item
        ValuableItems[slotState.Item] = nil
      end
    else
      slotState = SlotState:create({Item = nil, Count = 0})
    end
    Slots[i] = slotState
  end
end

-- performs multiple inventory management and cleanup tasks
function storeToSlot()
  local item = turtle.getItemDetail(WORKING_SLOT)
  local count = turtle.getItemCount(WORKING_SLOT)
  if (item == nil) then
    return
  end
  item = item.name
  Slots[WORKING_SLOT].Item = item
  Slots[WORKING_SLOT].Count = count

  local slot = 0
  local freeSpace = 0
  while (slot ~= -1 and slot < INVENTORY_SLOT_COUNT + 1) do
    slot = findNextSlotOfItemType(slot + 1, item)
    if (slot == -1 or slot == WORKING_SLOT) then
      slot = getNextFreeSlot(1)
      if (slot ~= -1) then
        transferItemsFromTo(WORKING_SLOT, slot, count)
      else
        -- TODO: handle case where there is no free slot left
        WriteLine("No free slot found")
      end
      return
    end
    -- we have an existing slot, check if there is enough space
    freeSpace = turtle.getItemSpace(slot)
    if (freeSpace ~= 0) then
      -- transfer as many items as possible
      local transferCount = math.min(freeSpace, count)
      transferItemsFromTo(WORKING_SLOT, slot, transferCount)
      count = count - transferCount
      if (count == 0) then
        return
      end
    end
    -- there is no space left in the current slot, continue searching
  end
  -- TODO: handle case where there is no free slot left
  WriteLine("No free slot found (2)")
end

-- performs multiple inventory management and cleanup tasks
function manageInventory()
  updateInventory()
  cleanUpInventory()
end

-- re-reads all internal slot states from the turtle
function updateInventory()
  -- update internal state
  for i = 1, INVENTORY_SLOT_COUNT do
    local item = turtle.getItemDetail(i)
    if (item == nil) then
      Slots[i].Item = nil
      Slots[i].Count = 0
    else
      Slots[i].Item = item.name
      Slots[i].Count = turtle.getItemCount(i)
    end
  end
end

-- transfers 'count' items from slot 'from' to slot 'to' and triggers an internal state update
function transferItemsFromTo(from, to, count)
  WriteLine("Transferring " .. count .. " items from slot " .. from .. " to slot " .. to)
  turtle.select(from)
  turtle.transferTo(to, count)
  updateInventory()
end

function findNextSlotOfItemType(start, item)
  if (item == nil) then
    return -1
  end
  for i = start, INVENTORY_SLOT_COUNT do
    if (Slots[i].Item == item and Slots[i].Count > 0) then
      return i
    end
  end
  return -1
end

-- returns the next free inventory slot starting at the provided index
function getNextFreeSlot(startIndex)
  for i = startIndex, INVENTORY_SLOT_COUNT do
    if (Slots[i].Count == 0) then
      return i
    end
  end
  return -1
end

-- Stacks as many items as possible
function stackifyInventory()
  for i = 1, INVENTORY_SLOT_COUNT do
    turtle.select(i)
    for j = i + 1, INVENTORY_SLOT_COUNT do
      -- if the current slot is full goto next
      local currentFreeSpace = turtle.getItemSpace(i)
      if (currentFreeSpace == 0 or Slots[i].Count == 0) then
        break
      end
      if (Slots[i].Item == Slots[j].Item and Slots[j].Count > 0) then
        local transferCount = math.min(currentFreeSpace, Slots[j].Count)
        transferItemsFromTo(j, i, transferCount)
      end
    end
  end
end

-- fills up empty item slots, starting from the beginning (stable)
function siftUp()
  for i = 1, INVENTORY_SLOT_COUNT do
    if (Slots[i].Count == 0) then
      for j = i + 1, INVENTORY_SLOT_COUNT do
        if (Slots[j].Count > 0) then
          transferItemsFromTo(j, i, Slots[j].Count)
        end
      end
    end
  end
end

function dropItem(slot, count)
  turtle.select(slot)
  turtle.drop(count)
  updateInventory()
end

-- cleans up the inventory
function cleanUpInventory()
  stackifyInventory()
  siftUp()

  -- are we running out of space?
  -- as everything is sifted up and in the top left corner of the inventory we only need to 
  -- check if the last slot is free
  local noSpace = Slots[INVENTORY_SLOT_COUNT].Count ~= 0

  if (noSpace) then
    -- drop unwanted items if there is not enough space to handle more initial / special items
    local hasSpaceDict = {}
    for i = 1, INVENTORY_SLOT_COUNT do
      local slot = Slots[i]
      -- check if all valuable items have space to expand (except bridge building material and torches) 
      if (isValuableItem(slot.Item)) then
        if (hasSpaceDict[slot.Item] == nil) then
          hasSpaceDict[slot.Item] = turtle.getItemSpace(i) ~= 0
        else
          hasSpaceDict[slot.Item] = hasSpaceDict[slot.Item] or turtle.getItemSpace(i) ~= 0
        end
      end
    end
    local needToDrop = false
    for i = 1, INVENTORY_SLOT_COUNT do
      local slot = Slots[i]
      if (hasSpaceDict[slot.Item] == false) then
        needToDrop = true
      end
    end
    if (needToDrop) then
      local droppedSuccessfully = false
      for i = 1, INVENTORY_SLOT_COUNT do
        local currentSlot = Slots[i]
        if not(isPreferredItem(currentSlot.Item)) then
          dropItem(i, currentSlot.Count)
          droppedSuccessfully = true
          break
        end
      end
      if (droppedSuccessfully == false) then
        for i = INVENTORY_SLOT_COUNT, 1, -1 do
          local currentSlot = Slots[i]
          if not(isValuableItem(currentSlot.Item)) then
            dropItem(i, currentSlot.Count)
            droppedSuccessfully = true
            break
          end
        end
      end
      if (droppedSuccessfully == false) then
        os.exit()
      end
    end
  end
end

function WriteLine(object)
  write(tostring(object) .. "\n")
end

function Write(text)
  write(text)
end

function ReadLine()
  return read()
end

function GetFuelLevel()
  return "~" .. tostring(turtle.getFuelLevel() / 80) .. " coal"
end

function Refuel()
  WriteLine("Fuel level was " .. GetFuelLevel())
  while(turtle.refuel(1)) do end
  WriteLine("New fuel level is " .. GetFuelLevel())
end

function PrintHelp()

end

-- builds a bridge if possible
function BuildBridge()
  local bridgeMaterialIndex = findNextSlotOfItemType(1, BridgeBlockItem)
  if (bridgeMaterialIndex ~= -1) then
    turtle.select(bridgeMaterialIndex)
    turtle.placeDown()
    -- TODO: this is costly, find a better way to handle this
    manageInventory()
    return true
  end
  return false
end

function DigForward()
  turtle.select(WORKING_SLOT)
  while (turtle.detect()) do
    turtle.dig()
    storeToSlot()
  end
  turtle.forward()
  while (turtle.detectUp()) do
    turtle.digUp()
    storeToSlot()
  end
  while not(turtle.detectDown()) do
    if not(BuildBridge()) then
      break
    end
  end
end

function Work(tunnelCount, tunnelLength)
  -- initialize inventory
  setupInventory()
  -- initial cleanup
  manageInventory()
  for i = 1, tunnelCount do
    DigForward()
    if (i % 2 == 0 and TorchItem ~= nil) then
      turtle.up()
      turtle.turnRight()
      while (turtle.detect()) do
        turtle.dig()
        storeToSlot()
      end
      local torchSlot = findNextSlotOfItemType(1, TorchItem)
      if (torchSlot ~= -1) then
        turtle.select(torchSlot)
        turtle.place()
        manageInventory()
      end
      turtle.turnLeft()
      turtle.down()
    end
    for j = 1, 2 do
      DigForward()
    end
    turtle.turnRight()
    for j = 1, tunnelLength do
      DigForward()
    end
    turtle.turnRight()
    turtle.turnRight()
    for j = 1, 2 * tunnelLength do
      DigForward()
    end
    turtle.turnRight()
    turtle.turnRight()
    for j = 1, tunnelLength do
      DigForward()
    end
    turtle.turnLeft()
  end
  -- move back to the starting position
  turtle.turnRight()
  turtle.turnRight()
  for i = 1, 3 * tunnelCount do
    turtle.forward()
  end
end

WriteLine("Enter the number of tunnels to dig:")
local tunnelCount = tonumber(ReadLine())
WriteLine("Enter the length of each tunnel:")
local tunnelLength = tonumber(ReadLine())
Work(tunnelCount, tunnelLength)
--DigForward()


--input = ReadLine()
--while(true)
--do
--  turtle.turnRight()
--end
BRIDGE_BLOCK_SLOT = 1
TORCH_SLOT = 2
CHEST_SLOT = 3
INVENTORY_SLOT_COUNT = 16
WORKING_SLOT = 16

BridgeBlockItem = nil
TorchItem = nil
ChestItem = nil

SlotState = { Item = nil, Count = 0 }
-- the ground area that needs to be covered per tunnel iteration
BlockGroundAreaPerTunnel = 0
-- the current step per tunnel iteration
CurrentStepPerTunnel = 0

function SlotState:create(o)
  o.parent = self
  return o
end

ValuableItems = {}
Slots = {}
-- register items of interest, determine item types for bridge building and torches
function IndexInventory()
  for i = 1, INVENTORY_SLOT_COUNT do
    local slotState = nil
    local currentCount = turtle.getItemCount(i)
    if (currentCount > 0) then
      slotState = SlotState:create({Item = turtle.getItemDetail(i).name, Count = currentCount})
      if (i == BRIDGE_BLOCK_SLOT) then
        WriteLine("Bridge block item found: " .. slotState.Item)
        BridgeBlockItem = slotState.Item
      elseif (i == TORCH_SLOT) then
        WriteLine("Torch item found: " .. slotState.Item)
        TorchItem = slotState.Item
        if (TorchItem ~= "minecraft:torch") then
          WriteLine("Torch item is not a torch, please insert torches into slot " .. TORCH_SLOT)
          -- exit if the torch item is not a torch
          error("Invalid torch item: " .. TorchItem .. ", expected: minecraft:torch")
        end
      elseif (i == CHEST_SLOT) then
        WriteLine("Chest item found: " .. slotState.Item)
        ChestItem = slotState.Item
        -- it should contain the word "chest" in the item name
        if (ChestItem == nil or string.find(ChestItem, "chest") == nil) then
          WriteLine("Chest item is not a chest, please insert a chest into slot " .. CHEST_SLOT)
          -- exit if the chest item is not a chest
          error("Invalid chest item: " .. ChestItem .. ", expected: <something containing 'chest'>")
        end
      end
    else
      slotState = SlotState:create({Item = nil, Count = 0})
    end
    Slots[i] = slotState
  end
end

-- performs multiple inventory management and cleanup tasks
function StoreToSlot()
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
    slot = FindNextSlotOfItemType(slot + 1, item)
    if (slot == -1 or slot == WORKING_SLOT) then
      slot = GetNextFreeSlot(1)
      if (slot ~= -1) then
        TransferItemsFromTo(WORKING_SLOT, slot, count)
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
      TransferItemsFromTo(WORKING_SLOT, slot, transferCount)
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
function ManageInventory()
  UpdateInventory()
  CleanUpInventory()
end

-- re-reads all internal slot states from the turtle
function UpdateInventory()
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
function TransferItemsFromTo(from, to, count)
  turtle.select(from)
  turtle.transferTo(to, count)
  UpdateInventory()
end

function FindNextSlotOfItemType(start, item)
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
function GetNextFreeSlot(startIndex)
  for i = startIndex, INVENTORY_SLOT_COUNT do
    if (Slots[i].Count == 0) then
      return i
    end
  end
  return -1
end

-- Stacks as many items as possible
function StackifyInventory()
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
        TransferItemsFromTo(j, i, transferCount)
      end
    end
  end
end

-- fills up empty item slots, starting from the beginning (stable)
function SiftUp()
  for i = 1, INVENTORY_SLOT_COUNT do
    if (Slots[i].Count == 0) then
      for j = i + 1, INVENTORY_SLOT_COUNT do
        if (Slots[j].Count > 0) then
          TransferItemsFromTo(j, i, Slots[j].Count)
        end
      end
    end
  end
end

function DropItem(slot, count)
  turtle.select(slot)
  turtle.drop(count)
  UpdateInventory()
end

-- cleans up the inventory
function CleanUpInventory()
  StackifyInventory()
  SiftUp()

  -- are we running out of space?
  -- as everything is sifted up and in the top left corner of the inventory we only need to 
  -- check if the last slot is free
  local noSpace = Slots[INVENTORY_SLOT_COUNT].Count ~= 0
  -- TODO: handle case where there is no free slot left
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

-- builds a bridge if possible
function BuildBridge()
  local bridgeMaterialIndex = FindNextSlotOfItemType(1, BridgeBlockItem)
  if (bridgeMaterialIndex ~= -1) then
    turtle.select(bridgeMaterialIndex)
    turtle.placeDown()
    local remainingBridgeBlocks = Slots[bridgeMaterialIndex].Count - 1
    Slots[bridgeMaterialIndex].Count = remainingBridgeBlocks
    -- only re-index the inventory if we suspect that the remaining bridge blocks in the slot are not enough to finish the tunnel
    if (BlockGroundAreaPerTunnel - CurrentStepPerTunnel <= remainingBridgeBlocks) then
      ManageInventory()
    end
    return true
  end
  return false
end

function BlockIsValuable(success, block)
  if (success and block ~= nil) then
    for i = 1, #ValuableItems do
      if (block.name == ValuableItems[i]) then
        return true
      end
    end
  end
  return false
end

function BlockIsValuableFront()
  local success, block = turtle.inspect()
  return BlockIsValuable(success, block)
end

function BlockIsValuableUp()
  local success, block = turtle.inspectUp()
  return BlockIsValuable(success, block)
end

function TryDigBlockFront()
  local success, block = turtle.inspect()
  if (not success) then
    -- no block to dig
    return true
  elseif (BlockIsValuable(true, block)) then
    -- block is valuable, do not dig
    WriteLine("Not digging valuable block: " .. block.name)
    return false
  end
  -- okay, we can dig the block
  turtle.dig()
  StoreToSlot()
  -- continue retrying until the block is gone
  while (turtle.detect()) do
    turtle.dig()
    StoreToSlot()
  end
  return true
end

function TryDigBlockUp()
  local success, block = turtle.inspectUp()
  if (not success) then
    -- no block to dig
    return true
  elseif (BlockIsValuable(true, block)) then
    -- block is valuable, do not dig
    WriteLine("Not digging valuable block: " .. block.name)
    return false
  end
  -- okay, we can dig the block
  turtle.digUp()
  StoreToSlot()
  -- continue retrying until the block is gone
  while (turtle.detectUp()) do
    turtle.digUp()
    StoreToSlot()
  end
  return true
end

function TryDigBlockDown()
  local success, block = turtle.inspectDown()
  if (not success) then
    -- no block to dig
    return true
  elseif (BlockIsValuable(true, block)) then
    -- block is valuable, do not dig
    WriteLine("Not digging valuable block: " .. block.name)
    return false
  end
  -- okay, we can dig the block
  turtle.digDown()
  StoreToSlot()
  return true
end

function DigForward(tunnelHeight, offset)
  turtle.select(WORKING_SLOT)
  local tempOffset = 0
  for j = 1, tunnelHeight - offset do
    TryDigBlockFront()
    if (j < tunnelHeight - offset) then
      if (TryDigBlockUp()) then
        turtle.up()
      else
        -- failed to dig to full height, break
        break
      end
    end
    tempOffset = j
  end
  -- move back to the starting position
  for j = 1, tempOffset do
    turtle.down()
  end
  tempOffset = 0
  local success = true
  -- it is possible that gravel or sand fell down while we were digging a block
  -- further up, so try to dig the block in front of us again (if any)
  TryDigBlockFront()
  -- try to advance
  while not(turtle.forward()) do
    -- if we can't advance, because there is a valuable block in front of us
    -- try further up to see if we can advance there
    if (not(turtle.up())) then
      success = false
      break
    end
    tempOffset = tempOffset + 1
  end
  if (not success) then
    -- we can't advance, move back to the starting position
    for j = 1, tempOffset do
      turtle.down()
    end
    -- and fail
    return -1
  end
  -- we advanced, and the block beneath us might be invaluable, try to dig it
  -- we know that through the tempOffset, as we managed to just move forward
  if (tempOffset == 0) then
    -- try to correct the offset to get back to the expected height
    while (offset > 0 and TryDigBlockDown()) do
      turtle.down()
      offset = offset - 1
    end
  end
  CurrentStepPerTunnel = CurrentStepPerTunnel + 1
  -- we advanced, try to build a bridge, if necessary
  if (offset == 0) then
    -- only build a bridge if we are at the expected height
    while not(turtle.detectDown()) do
      if not(BuildBridge()) then
        break
      end
    end
  end
  -- we advanced, return the number of blocks moved up (the new offset)
  return offset + tempOffset
end

function TryPlaceTorch()
  local torchSlot = FindNextSlotOfItemType(1, TorchItem)
  if (torchSlot ~= -1) then
    turtle.select(torchSlot)
    turtle.place()
    Slots[torchSlot].Count = Slots[torchSlot].Count - 1
    -- try to refill the torch slot if possible
    local otherTorchSlot = FindNextSlotOfItemType(torchSlot + 1, TorchItem)
    if (otherTorchSlot ~= -1) then
      TransferItemsFromTo(otherTorchSlot, torchSlot, 1)
    end
    return true
  end
  return false
end

-- checks if the turtle's inventory should be flushed / unloaded to a chest
-- assumes that stackify and siftup have been called before
-- flushing is necessary if the inventory is more than half full
function RequiresInventoryFlush()
  -- as everything is sifted up and in the top left corner of the inventory we only need to
  -- check if the slot at index INVENTORY_SLOT_COUNT / 2 is not empty
  return Slots[(INVENTORY_SLOT_COUNT / 2) + 1].Count > 0
end

-- unloads the turtle's inventory into a chest, assuming the chest is in front of the turtle
function TransferToChest()
  local hasBridgeBlocks = false
  for i = 1, INVENTORY_SLOT_COUNT do
    -- keep torches, chests, and at least one stack of bridge blocks
    if (Slots[i].Count > 0 and Slots[i].Item ~= TorchItem and Slots[i].Item ~= ChestItem) then
      -- also keep at least one stack of bridge blocks
      if (not hasBridgeBlocks and Slots[i].Item == BridgeBlockItem) then
        hasBridgeBlocks = true
      else
        turtle.select(i)
        if (not(turtle.drop())) then
          error("Failed to drop item")
          return false
        end
        UpdateInventory()
      end
    end
  end
end

function TryPlaceChest()
  if (ChestItem == nil) then
    return false
  end
  local chestSlot = FindNextSlotOfItemType(1, ChestItem)
  if (chestSlot ~= -1) then
    turtle.select(chestSlot)
    turtle.place()
    Slots[chestSlot].Count = Slots[chestSlot].Count - 1
    -- try to refill the chest slot if possible
    local otherChestSlot = FindNextSlotOfItemType(chestSlot + 1, ChestItem)
    if (otherChestSlot ~= -1) then
      TransferItemsFromTo(otherChestSlot, chestSlot, 1)
    end
    return true
  end
  return false
end

function MoveTunnelBack(tunnelLength, tunnelHeight, offset)
  for j = 1, tunnelLength do
    -- try to just move back, preferring to go down to the expected height
    if (turtle.forward()) then
      while (offset > 0 and turtle.down()) do
        offset = offset - 1
      end
    else
      -- if that doesn't work, try to move back using the same algorithm with which we got here
      offset = DigForward(tunnelHeight, offset)
      if (offset == -1) then
        -- this should never happen, as we have already dug the tunnel
        error("Failed to move back")
      end
    end
  end
  return offset
end

function DigTunnel(tunnelLength, tunnelHeight, torchesAtEnd, offset, turnAround)
  for j = 1, tunnelLength do
    local newOffset = DigForward(tunnelHeight, offset)
    if (newOffset == -1) then
      -- move back to the starting position
      turtle.turnRight()
      turtle.turnRight()
      -- "dig" back around any obstacles to the starting position,
      -- return the final offset to the caller
      return MoveTunnelBack(j - 1, tunnelHeight, offset)
    end
    offset = newOffset
  end
  if (not(turnAround)) then
    return offset
  end
  local wayBack = tunnelLength
  if (torchesAtEnd and TorchItem ~= nil) then
    -- we can always go back one step, as we have already dug the tunnel
    turtle.back()
    TryPlaceTorch()
    wayBack = wayBack - 1
  end
  turtle.turnRight()
  turtle.turnRight()
  return MoveTunnelBack(wayBack, tunnelHeight, offset)
end

function Work(tunnelCount, tunnelLength, tunnelHeight, torchPlacement, torchesAtEnd)
  -- initialize inventory
  IndexInventory()
  local returnedOffset = 0
  local offset = 0
  local blocksMoved = 0
  for i = 1, tunnelCount do
    CurrentStepPerTunnel = 0
    WriteLine("Tunnel " .. i .. " of " .. tunnelCount .. " (fuel: " .. GetFuelLevel() .. ")")
    returnedOffset = DigForward(tunnelHeight, offset)
    if (returnedOffset == -1) then
      break
    end
    offset = returnedOffset
    blocksMoved = blocksMoved + 1
    -- detect changes in inventory and clean up
    ManageInventory()
    -- place torches every torchPlacement tunnels
    if (i % torchPlacement == 0 and TorchItem ~= nil) then
      turtle.turnRight()
      -- try to find a free slot for torches
      local tempOffset = offset
      while (not(TryDigBlockFront()) and tempOffset < tunnelHeight and turtle.up()) do
        tempOffset = tempOffset + 1
      end
      -- if we managed to dig a block, place a torch
      if (tempOffset < tunnelHeight and TryDigBlockFront()) then
        TryPlaceTorch()
      end
      -- return to the starting position regardless of success
      while (tempOffset > offset) do
        turtle.down()
        tempOffset = tempOffset - 1
      end
      turtle.turnLeft()
    end
    -- check if the inventory needs to be flushed
    local returnToHome = false
    local previosBlockWasEmpty = false
    if (RequiresInventoryFlush() and ChestItem ~= nil) then
      -- find an empty slot on the left of us to place a chest
      turtle.turnLeft()
      local tempOffset = offset
      for tempOffsetIterator = tempOffset, tunnelHeight - 1 do
        tempOffset = tempOffsetIterator
        if (not(TryDigBlockFront())) then
          previosBlockWasEmpty = false
        elseif (previosBlockWasEmpty) then
          -- we found two empty blocks in a row, place a chest
          turtle.down()
          tempOffset = tempOffset - 1
          if (not TryPlaceChest()) then
            WriteLine("Failed to place chest, returning to home")
            returnToHome = true
          else
            TransferToChest()
          end
          break
        else
          previosBlockWasEmpty = true
        end
        if (not(turtle.up())) then
          error("Failed to move up while trying to place chest")
        end
      end
      while (tempOffset > offset) do
        turtle.down()
        tempOffset = tempOffset - 1
      end
      turtle.turnRight()
    end
    if (returnToHome) then
      break
    end
    for j = 1, 2 do
      returnedOffset = DigForward(tunnelHeight, offset)
      if (returnedOffset == -1) then
        break
      end
      blocksMoved = blocksMoved + 1
      offset = returnedOffset
    end
    if (returnedOffset == -1) then
      break
    end
    turtle.turnRight()
    offset = DigTunnel(tunnelLength, tunnelHeight, torchesAtEnd, offset, true)
    offset = DigTunnel(tunnelLength, tunnelHeight, torchesAtEnd, offset, true)
    turtle.turnLeft()
  end
  -- move back to the starting position
  turtle.turnRight()
  turtle.turnRight()
  MoveTunnelBack(blocksMoved, tunnelHeight, offset)
end

WriteLine("Provide the following items in the following slots (1-indexed):")
WriteLine("Bridge item: slot " .. BRIDGE_BLOCK_SLOT)
WriteLine("Torch item: slot " .. TORCH_SLOT)
WriteLine("Chest item: slot " .. CHEST_SLOT)
WriteLine("Leave slot " .. WORKING_SLOT .. " empty at all times (working register)")
WriteLine("Enter the number of tunnels to dig:")
local tunnelCount = tonumber(ReadLine())
WriteLine("Enter the length of each tunnel:")
local tunnelLength = tonumber(ReadLine())
WriteLine("Enter tunnel height:")
local tunnelHeight = tonumber(ReadLine())
WriteLine("Torch placement every nth tunnel (n):")
local torchPlacement = tonumber(ReadLine())
WriteLine("Torches at end of tunnel? (y/n)")
local torchesAtEnd = ReadLine() == "y"
WriteLine("Perhaps there are valuable blocks you want to mine youself (e.g., with a fortune pickaxe)?")
WriteLine("Enter IDs of blocks to navigate around, one per line, empty line to finish:")
local valuableItem = ReadLine()
local itemIndex = 1
while (valuableItem ~= "") do
  ValuableItems[itemIndex] = valuableItem
  itemIndex = itemIndex + 1
  valuableItem = ReadLine()
end
-- every 3 blocks, dig one tunnel in each direction (left, right) leaving two solid blocks between each tunnel iteration
BlockGroundAreaPerTunnel = 3 + 2 + (2 * tunnelLength)
Work(tunnelCount, tunnelLength, tunnelHeight, torchPlacement, torchesAtEnd)
WriteLine("Done")
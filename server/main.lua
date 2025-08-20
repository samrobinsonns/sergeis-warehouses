local QBCore = exports['qb-core']:GetCoreObject()

-- Simplified SQL schema for single warehouse type
CreateThread(function()
    MySQL.query([[CREATE TABLE IF NOT EXISTS `warehouses` (
        `id` INT NOT NULL AUTO_INCREMENT,
        `citizenid` VARCHAR(50) NOT NULL,
        `purchased_slots` INT NOT NULL DEFAULT 0,
        `created_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`id`),
        UNIQUE KEY `uniq_owner` (`citizenid`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;]])

    MySQL.query([[CREATE TABLE IF NOT EXISTS `warehouse_storage` (
        `id` INT NOT NULL AUTO_INCREMENT,
        `warehouse_id` INT NOT NULL,
        `slot_index` INT NOT NULL,
        `item_name` VARCHAR(32) NULL,
        `item_count` INT NOT NULL DEFAULT 0,
        `created_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`id`),
        UNIQUE KEY `uniq_slot` (`warehouse_id`,`slot_index`),
        CONSTRAINT `fk_storage_wh` FOREIGN KEY (`warehouse_id`) REFERENCES `warehouses` (`id`) ON DELETE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;]])
end)

-- Get warehouse ID for a citizen
local function getWarehouseIdForCitizen(citizenId)
    local result = MySQL.query.await('SELECT id FROM warehouses WHERE citizenid = ?', { citizenId })
    return result and result[1] and result[1].id
end

-- Get warehouse data for a citizen
local function getWarehouseData(citizenId)
    local result = MySQL.query.await('SELECT * FROM warehouses WHERE citizenid = ?', { citizenId })
    return result and result[1]
end

-- Buy warehouse
RegisterNetEvent('sergeis-warehouse:server:buyWarehouse', function()
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    if not player then 
        return 
    end
    
    local citizenId = player.PlayerData.citizenid
    
    -- Check if player already owns a warehouse
    if getWarehouseIdForCitizen(citizenId) then
        TriggerClientEvent('QBCore:Notify', src, 'You already own a warehouse', 'error')
        return
    end
    
    -- Check if player has enough money
    if player.PlayerData.money[Config.PurchaseAccount] < Config.Warehouse.price then
        TriggerClientEvent('QBCore:Notify', src, 'Not enough money', 'error')
        return
    end
    
    -- Remove money
    player.Functions.RemoveMoney(Config.PurchaseAccount, Config.Warehouse.price)
    
    -- Create warehouse with 1 slot by default
    local success = MySQL.insert.await('INSERT INTO warehouses (citizenid, purchased_slots) VALUES (?, ?)', {
        citizenId, 1 -- Start with 1 slot
    })
    
    if success then
        TriggerClientEvent('QBCore:Notify', src, 'Warehouse purchased successfully! You now have 1 storage slot.', 'success')
        TriggerClientEvent('sergeis-warehouse:client:refreshOwnership', src)
    else
        -- Refund money if database insert failed
        player.Functions.AddMoney(Config.PurchaseAccount, Config.Warehouse.price)
        TriggerClientEvent('QBCore:Notify', src, 'Purchase failed, please try again', 'error')
    end
end)

-- Buy additional storage slots
RegisterNetEvent('sergeis-warehouse:server:buyStorageSlots', function(slotCount)
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    if not player then return end
    
    local citizenId = player.PlayerData.citizenid
    local warehouse = getWarehouseData(citizenId)
    
    if not warehouse then
        TriggerClientEvent('QBCore:Notify', src, 'You do not own a warehouse', 'error')
        return
    end
    
    local totalCost = slotCount * Config.Warehouse.slotPrice
    local newTotalSlots = warehouse.purchased_slots + slotCount
    
    -- Check if new total exceeds maximum
    if newTotalSlots > Config.Warehouse.maxSlots then
        TriggerClientEvent('QBCore:Notify', src, 'Cannot exceed maximum storage slots', 'error')
        return
    end
    
    -- Check if player has enough money
    if player.PlayerData.money[Config.PurchaseAccount] < totalCost then
        TriggerClientEvent('QBCore:Notify', src, 'Not enough money', 'error')
        return
    end
    
    -- Remove money and update warehouse
    player.Functions.RemoveMoney(Config.PurchaseAccount, totalCost)
    
    local success = MySQL.update.await('UPDATE warehouses SET purchased_slots = ? WHERE id = ?', {
        newTotalSlots, warehouse.id
    })
    
    if success then
        TriggerClientEvent('QBCore:Notify', src, 'Storage slots purchased successfully!', 'success')
        TriggerClientEvent('sergeis-warehouse:client:refreshOwnership', src)
        TriggerClientEvent('sergeis-warehouse:client:refreshStorageGrid', src)
        TriggerClientEvent('sergeis-warehouse:client:refreshCrates', src)
    else
        -- Refund money if database update failed
        player.Functions.AddMoney(Config.PurchaseAccount, totalCost)
        TriggerClientEvent('QBCore:Notify', src, 'Purchase failed, please try again', 'error')
    end
end)

-- Sell warehouse
RegisterNetEvent('sergeis-warehouse:server:sellWarehouse', function()
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    if not player then return end
    
    local citizenId = player.PlayerData.citizenid
    local warehouseId = getWarehouseIdForCitizen(citizenId)
    
    if not warehouseId then
        TriggerClientEvent('QBCore:Notify', src, 'You do not own a warehouse', 'error')
        return
    end
    
    -- Get warehouse data to calculate refund
    local warehouse = getWarehouseData(citizenId)
    local totalRefund = Config.Warehouse.sellPrice
    
    -- Add refund for purchased slots (optional - you can remove this if you don't want to refund slots)
    -- local slotRefund = warehouse.purchased_slots * Config.Warehouse.slotPrice * 0.5 -- 50% refund on slots
    -- totalRefund = totalRefund + slotRefund
    
    -- Delete warehouse (cascades to storage)
    local success = MySQL.query.await('DELETE FROM warehouses WHERE id = ?', { warehouseId })
    
    if success then
        -- Give player the sell price
        local oldMoney = player.PlayerData.money[Config.SellAccount] or 0
        local moneyAdded = player.Functions.AddMoney(Config.SellAccount, totalRefund)
        
        -- If AddMoney fails, try alternative method
        if not moneyAdded then
            -- Try to manually update the money
            if player.PlayerData.money[Config.SellAccount] then
                player.PlayerData.money[Config.SellAccount] = player.PlayerData.money[Config.SellAccount] + totalRefund
                moneyAdded = true
            end
        end
        
        local newMoney = player.PlayerData.money[Config.SellAccount] or 0
        
        TriggerClientEvent('QBCore:Notify', src, 'Warehouse sold for $' .. totalRefund, 'success')
        TriggerClientEvent('sergeis-warehouse:client:onWarehouseSold', src)
        TriggerClientEvent('sergeis-warehouse:client:refreshOwnership', src)
        
    else
        TriggerClientEvent('QBCore:Notify', src, 'Failed to sell warehouse', 'error')
    end
end)

-- Get warehouse info for client
RegisterNetEvent('sergeis-warehouse:server:getWarehouseInfo', function()
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    if not player then return end
    
    local citizenId = player.PlayerData.citizenid
    local warehouse = getWarehouseData(citizenId)
    
    local info = {
        owned = false,
        id = nil,
        purchased_slots = 0,
        max_slots = Config.Warehouse.maxSlots,
        slot_price = Config.Warehouse.slotPrice,
        warehouse_price = Config.Warehouse.price,
        sell_price = Config.Warehouse.sellPrice
    }
    
    if warehouse then
        info.owned = true
        info.id = warehouse.id
        info.purchased_slots = warehouse.purchased_slots
    end
    
    TriggerClientEvent('sergeis-warehouse:client:receiveWarehouseInfo', src, info)
end)

-- Get storage contents
RegisterNetEvent('sergeis-warehouse:server:getStorageContents', function()
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    if not player then return end
    
    local citizenId = player.PlayerData.citizenid
    local warehouseId = getWarehouseIdForCitizen(citizenId)
    
    if not warehouseId then
        TriggerClientEvent('QBCore:Notify', src, 'You do not own a warehouse', 'error')
        return
    end
    
    local storage = MySQL.query.await('SELECT * FROM warehouse_storage WHERE warehouse_id = ? ORDER BY slot_index', { warehouseId })
    
    TriggerClientEvent('sergeis-warehouse:client:receiveStorageContents', src, storage or {})
end)

-- Open warehouse crate storage
RegisterNetEvent('sergeis-warehouse:server:openCrateStorage', function(crateIndex)
    
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    if not player then 
        return 
    end
    
    local citizenId = player.PlayerData.citizenid
    
    local warehouseId = getWarehouseIdForCitizen(citizenId)
    if not warehouseId then
        TriggerClientEvent('QBCore:Notify', src, 'You do not own a warehouse', 'error')
        return
    end
    
    -- Check if crate is within purchased slots
    local warehouse = getWarehouseData(citizenId)
    if crateIndex > warehouse.purchased_slots then
        TriggerClientEvent('QBCore:Notify', src, 'This storage crate is not available', 'error')
        return
    end
    
    -- Create unique stash ID for this crate
    local stashId = 'warehouse_crate_' .. warehouseId .. '_' .. crateIndex
    local stashLabel = 'Warehouse Crate ' .. crateIndex
    
    -- Open the stash using the configured inventory system
    if Config.InventorySystem == 'ox_inventory' and exports.ox_inventory then
        
        -- Create the stash if it doesn't exist
        local success = exports.ox_inventory:RegisterStash(stashId, stashLabel, Config.Storage.ox_inventory.maxSlots, Config.Storage.ox_inventory.maxWeight)
        
        -- Open the stash for the player using the correct ox_inventory function
        TriggerClientEvent('ox_inventory:openInventory', src, 'stash', stashId)
        
    elseif Config.InventorySystem == 'qb-inventory' and exports['qb-inventory'] then
        
        -- Open the stash using QBCore's stash system
        TriggerClientEvent('inventory:client:SetCurrentStash', src, stashId)
        exports['qb-inventory']:openInventory(src, 'stash', stashId)
        
    else
        
        -- Fallback to ox_inventory if available
        if exports.ox_inventory then
            local success = exports.ox_inventory:RegisterStash(stashId, stashLabel, Config.Storage.ox_inventory.maxSlots, Config.Storage.ox_inventory.maxWeight)
            
            TriggerClientEvent('ox_inventory:openInventory', src, 'stash', stashId)
        else
            TriggerClientEvent('QBCore:Notify', src, 'Inventory system not available', 'error')
        end
    end
end)

-- Store item in warehouse
RegisterNetEvent('sergeis-warehouse:server:storeItem', function(slotIndex, itemName, itemCount)
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    if not player then return end
    
    local citizenId = player.PlayerData.citizenid
    local warehouseId = getWarehouseIdForCitizen(citizenId)
    
    if not warehouseId then
        TriggerClientEvent('QBCore:Notify', src, 'You do not own a warehouse', 'error')
        return
    end
    
    -- Check if slot is available (within purchased slots)
    local warehouse = getWarehouseData(citizenId)
    if slotIndex >= warehouse.purchased_slots then
        TriggerClientEvent('QBCore:Notify', src, 'Storage slot not available', 'error')
        return
    end
    
    -- Check if player has the item
    local playerItem = player.Functions.GetItemByName(itemName)
    if not playerItem or playerItem.amount < itemCount then
        TriggerClientEvent('QBCore:Notify', src, 'Not enough items', 'error')
        return
    end
    
    -- Remove item from player and add to warehouse
    player.Functions.RemoveItem(itemName, itemCount)
    
    -- Check if slot already has items
    local existingSlot = MySQL.query.await('SELECT * FROM warehouse_storage WHERE warehouse_id = ? AND slot_index = ?', {
        warehouseId, slotIndex
    })
    
    if existingSlot and #existingSlot > 0 then
        -- Update existing slot
        MySQL.update.await('UPDATE warehouse_storage SET item_count = item_count + ? WHERE warehouse_id = ? AND slot_index = ?', {
            itemCount, warehouseId, slotIndex
        })
    else
        -- Create new slot
        MySQL.insert.await('INSERT INTO warehouse_storage (warehouse_id, slot_index, item_name, item_count) VALUES (?, ?, ?, ?)', {
            warehouseId, slotIndex, itemName, itemCount
        })
    end
    
    TriggerClientEvent('QBCore:Notify', src, 'Item stored successfully', 'success')
    TriggerClientEvent('sergeis-warehouse:client:refreshStorage', src)
end)

-- Retrieve item from warehouse
RegisterNetEvent('sergeis-warehouse:server:retrieveItem', function(slotIndex, itemCount)
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    if not player then return end
    
    local citizenId = player.PlayerData.citizenid
    local warehouseId = getWarehouseIdForCitizen(citizenId)
    
    if not warehouseId then
        TriggerClientEvent('QBCore:Notify', src, 'You do not own a warehouse', 'error')
        return
    end
    
    -- Get slot contents
    local slot = MySQL.query.await('SELECT * FROM warehouse_storage WHERE warehouse_id = ? AND slot_index = ?', {
        warehouseId, slotIndex
    })
    
    if not slot or #slot == 0 then
        TriggerClientEvent('QBCore:Notify', src, 'Slot is empty', 'error')
        return
    end
    
    local slotData = slot[1]
    if itemCount > slotData.item_count then
        itemCount = slotData.item_count
    end
    
    -- Add item to player
    player.Functions.AddItem(slotData.item_name, itemCount)
    
    -- Update or remove slot
    if itemCount >= slotData.item_count then
        MySQL.query.await('DELETE FROM warehouse_storage WHERE warehouse_id = ? AND slot_index = ?', {
            warehouseId, slotIndex
        })
    else
        MySQL.update.await('UPDATE warehouse_storage SET item_count = item_count - ? WHERE warehouse_id = ? AND slot_index = ?', {
            itemCount, warehouseId, slotIndex
        })
    end
    
    TriggerClientEvent('QBCore:Notify', src, 'Item retrieved successfully', 'success')
    TriggerClientEvent('sergeis-warehouse:client:refreshStorage', src)
end)



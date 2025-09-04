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

    -- Create warehouse sharing table for access control
    MySQL.query([[CREATE TABLE IF NOT EXISTS `warehouse_sharing` (
        `id` INT NOT NULL AUTO_INCREMENT,
        `warehouse_id` INT NOT NULL,
        `owner_citizenid` VARCHAR(50) NOT NULL,
        `shared_with_citizenid` VARCHAR(50) NOT NULL,
        `permission_level` ENUM('read', 'write', 'admin') NOT NULL DEFAULT 'read',
        `created_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
        `expires_at` TIMESTAMP NULL DEFAULT NULL,
        PRIMARY KEY (`id`),
        UNIQUE KEY `uniq_sharing` (`warehouse_id`, `shared_with_citizenid`),
        CONSTRAINT `fk_sharing_wh` FOREIGN KEY (`warehouse_id`) REFERENCES `warehouses` (`id`) ON DELETE CASCADE,
        INDEX `idx_shared_with` (`shared_with_citizenid`),
        INDEX `idx_owner` (`owner_citizenid`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;]])

    -- Create warehouse access log table (optional, for audit purposes)
    MySQL.query([[CREATE TABLE IF NOT EXISTS `warehouse_access_log` (
        `id` INT NOT NULL AUTO_INCREMENT,
        `warehouse_id` INT NOT NULL,
        `player_citizenid` VARCHAR(50) NOT NULL,
        `action` VARCHAR(100) NOT NULL,
        `timestamp` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`id`),
        CONSTRAINT `fk_log_wh` FOREIGN KEY (`warehouse_id`) REFERENCES `warehouses` (`id`) ON DELETE CASCADE,
        INDEX `idx_player` (`player_citizenid`),
        INDEX `idx_timestamp` (`timestamp`)
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

-- Get the price for a specific slot
local function getSlotPrice(slotNumber)
    local price = Config.Warehouse.slotPrices[slotNumber] or Config.Warehouse.slotPrice
    return price
end

-- Check if player has access to warehouse
local function hasWarehouseAccess(citizenId, warehouseId, requiredPermission)
    -- Always log this critical function call
    print(string.format('[WAREHOUSE] hasWarehouseAccess CALLED - citizenId=%s, warehouseId=%s, permission=%s', citizenId, warehouseId, requiredPermission))
    
    if Config.Debug then
        print(string.format('[WAREHOUSE DEBUG] hasWarehouseAccess: citizenId=%s, warehouseId=%s, requiredPermission=%s', citizenId, warehouseId, requiredPermission))
    end
    
    -- Check ownership first
    local warehouse = MySQL.query.await('SELECT * FROM warehouses WHERE id = ? AND citizenid = ?', { warehouseId, citizenId })
    local isOwner = warehouse and #warehouse > 0
    
    print(string.format('[WAREHOUSE] OWNERSHIP CHECK - citizenId=%s, warehouseId=%s, isOwner=%s', citizenId, warehouseId, isOwner and 'YES' or 'NO'))
    
    if Config.Debug then
        print(string.format('[WAREHOUSE DEBUG] hasWarehouseAccess: Ownership query result - found: %s', isOwner and 'yes' or 'no'))
    end
    
    if isOwner then
        print('[WAREHOUSE] OWNER ACCESS - Player is owner, granting full access')
        return true -- Owner has full access
    end
    
    print('[WAREHOUSE] SHARING CHECK - Player is not owner, checking sharing permissions')
    
    if Config.Debug then
        print('[WAREHOUSE DEBUG] hasWarehouseAccess: Player is not owner, checking sharing permissions')
    end
    
    -- Check sharing permissions
    local sharing = MySQL.query.await('SELECT * FROM warehouse_sharing WHERE warehouse_id = ? AND shared_with_citizenid = ? AND (expires_at IS NULL OR expires_at > NOW())', {
        warehouseId, citizenId
    })
    
    local sharingCount = sharing and #sharing or 0
    print(string.format('[WAREHOUSE] SHARING RECORDS - Found %s sharing records for citizenId=%s in warehouse=%s', sharingCount, citizenId, warehouseId))
    
    if Config.Debug then
        print(string.format('[WAREHOUSE DEBUG] hasWarehouseAccess: Sharing records found: %s', sharingCount))
    end
    
    if sharingCount == 0 then
        print('[WAREHOUSE] ACCESS DENIED - No sharing records found')
        return false
    end
    
    local shareData = sharing[1]
    print(string.format('[WAREHOUSE] SHARE DATA - permission_level: %s, expires_at: %s', 
        shareData.permission_level, shareData.expires_at or 'NULL'))
    
    if Config.Debug then
        print(string.format('[WAREHOUSE DEBUG] hasWarehouseAccess: Share data - permission_level: %s, expires_at: %s', 
            shareData.permission_level, shareData.expires_at or 'NULL'))
    end
    
    local permissionLevels = { read = 1, write = 2, admin = 3 }
    local requiredLevel = permissionLevels[requiredPermission] or 1
    local userLevel = permissionLevels[shareData.permission_level] or 1
    
    local accessGranted = userLevel >= requiredLevel
    print(string.format('[WAREHOUSE] PERMISSION CHECK - required: %s, user: %s, granted: %s', 
        requiredLevel, userLevel, accessGranted and 'YES' or 'NO'))
    
    if Config.Debug then
        print(string.format('[WAREHOUSE DEBUG] hasWarehouseAccess: Permission check - required: %s, user: %s, granted: %s', 
            requiredLevel, userLevel, accessGranted))
    end
    
    return accessGranted
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

-- Buy specific storage slot (new function for individual slot pricing)
RegisterNetEvent('sergeis-warehouse:server:buySpecificSlot', function(slotNumber)
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    if not player then return end
    
    local citizenId = player.PlayerData.citizenid
    local warehouse = getWarehouseData(citizenId)
    
    if not warehouse then
        TriggerClientEvent('QBCore:Notify', src, 'You do not own a warehouse', 'error')
        return
    end
    
    -- Check if slot number is valid
    if slotNumber < 1 or slotNumber > Config.Warehouse.maxSlots then
        TriggerClientEvent('QBCore:Notify', src, 'Invalid slot number', 'error')
        return
    end
    
    -- Check if slot is already purchased
    if slotNumber <= warehouse.purchased_slots then
        TriggerClientEvent('QBCore:Notify', src, 'This slot is already purchased', 'error')
        return
    end
    
    -- Check if slot can be purchased (must be consecutive)
    if slotNumber > warehouse.purchased_slots + 1 then
        TriggerClientEvent('QBCore:Notify', src, 'You must purchase slots in order', 'error')
        return
    end
    
    -- Get the price for this specific slot
    local slotPrice = getSlotPrice(slotNumber)
    
    -- Check if player has enough money
    if player.PlayerData.money[Config.PurchaseAccount] < slotPrice then
        TriggerClientEvent('QBCore:Notify', src, 'Not enough money. Slot ' .. slotNumber .. ' costs $' .. slotPrice, 'error')
        return
    end
    
    -- Remove money and update warehouse
    player.Functions.RemoveMoney(Config.PurchaseAccount, slotPrice)
    
    local success = MySQL.update.await('UPDATE warehouses SET purchased_slots = ? WHERE id = ?', {
        slotNumber, warehouse.id
    })
    
    if success then
        TriggerClientEvent('QBCore:Notify', src, 'Slot ' .. slotNumber .. ' purchased successfully for $' .. slotPrice, 'success')
        TriggerClientEvent('sergeis-warehouse:client:refreshOwnership', src)
        TriggerClientEvent('sergeis-warehouse:client:refreshStorageGrid', src)
        TriggerClientEvent('sergeis-warehouse:client:refreshCrates', src)
    else
        -- Refund money if database update failed
        player.Functions.AddMoney(Config.PurchaseAccount, slotPrice)
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


-- Variable to store player warehouse buckets
local playerWarehouseBuckets = {}

-- Validate player bucket access
local function validatePlayerBucket(src, warehouseId)
    local player = QBCore.Functions.GetPlayer(src)
    if not player then 
        print(string.format('[WAREHOUSE DEBUG] validatePlayerBucket: Player not found for src %s', src))
        return false 
    end
    
    local currentBucket = playerWarehouseBuckets[src]
    print(string.format('[WAREHOUSE DEBUG] validatePlayerBucket: src=%s, warehouseId=%s, currentBucket=%s', 
        src, warehouseId, currentBucket or 'nil'))
    
    if not currentBucket or currentBucket <= 0 then 
        print(string.format('[WAREHOUSE DEBUG] validatePlayerBucket: No valid bucket found for src %s', src))
        return false 
    end
    
    -- Check if player is in the correct bucket for their warehouse
    -- Now using warehouse-based buckets (warehouseId) instead of player-based buckets
    local expectedBucket = warehouseId
    
    print(string.format('[WAREHOUSE DEBUG] validatePlayerBucket: src=%s, warehouseId=%s, currentBucket=%s, expectedBucket=%s, match=%s', 
        src, warehouseId, currentBucket, expectedBucket, currentBucket == expectedBucket and 'YES' or 'NO'))
    
    return currentBucket == expectedBucket
end

-- Set routing bucket for warehouse instancing
RegisterNetEvent('sergeis-warehouse:server:setBucket', function(bucketId)
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    if not player then return end
    
    if bucketId and bucketId > 0 then
        -- Use warehouse-based buckets so all players in the same warehouse can see each other
        -- This is crucial for shared warehouse functionality
        local warehouseBucketId = bucketId
        
        -- Set player to the warehouse bucket (shared by all players in that warehouse)
        SetPlayerRoutingBucket(src, warehouseBucketId)
        
        -- Use 'inactive' lockdown mode to allow shared access
        SetRoutingBucketEntityLockdownMode(warehouseBucketId, 'inactive')
        
        -- Store the bucket ID for this player
        playerWarehouseBuckets[src] = warehouseBucketId
        
        print(string.format('[WAREHOUSE] Player %s (%s) entered warehouse bucket %d (shared bucket)', 
            player.PlayerData.name, player.PlayerData.citizenid, warehouseBucketId))
    else
        -- Return player to default bucket (0)
        local currentBucket = playerWarehouseBuckets[src]
        if currentBucket then
            SetPlayerRoutingBucket(src, 0)
            playerWarehouseBuckets[src] = nil
            print(string.format('[WAREHOUSE] Player %s (%s) returned to default bucket from %d', 
                player.PlayerData.name, player.PlayerData.citizenid, currentBucket))
        else
            SetPlayerRoutingBucket(src, 0)
            print(string.format('[WAREHOUSE] Player %s (%s) returned to default bucket', 
                player.PlayerData.name, player.PlayerData.citizenid))
        end
    end
end)







-- Cleanup on resource stop
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        print('[WAREHOUSE] Resource stop event triggered')
        
        -- Simple cleanup without complex logic
        for playerId, bucketId in pairs(playerWarehouseBuckets) do
            if bucketId and bucketId > 0 then
                SetPlayerRoutingBucket(playerId, 0)
                print(string.format('[WAREHOUSE] Player %d returned to default bucket on resource stop', playerId))
            end
        end
        
        -- Clear the buckets table
        playerWarehouseBuckets = {}
        print('[WAREHOUSE] Resource stop cleanup completed')
    end
end)

-- Recovery event for clients
RegisterNetEvent('sergeis-warehouse:server:requestRecovery', function()
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    if not player then return end
    
    -- Reset player's routing bucket if they have one
    if playerWarehouseBuckets[src] then
        SetPlayerRoutingBucket(src, 0)
        playerWarehouseBuckets[src] = nil
        print(string.format('[WAREHOUSE] Recovery: Player %s (%s) returned to default bucket', 
            player.PlayerData.name, player.PlayerData.citizenid))
    end
    
    -- Notify client that recovery is complete
    TriggerClientEvent('sergeis-warehouse:client:recoveryComplete', src)
end)

-- Handle player disconnection
AddEventHandler('playerDropped', function(reason)
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    if player and playerWarehouseBuckets[src] then
        print(string.format('[WAREHOUSE] Player %s disconnected from warehouse bucket %d', 
            player.PlayerData.name, playerWarehouseBuckets[src]))
        playerWarehouseBuckets[src] = nil
    end
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
    
    -- Validate that player is in the correct bucket
    if not validatePlayerBucket(src, warehouseId) then
        TriggerClientEvent('QBCore:Notify', src, 'Access denied: Invalid warehouse session', 'error')
        return
    end
    
    local storage = MySQL.query.await('SELECT * FROM warehouse_storage WHERE warehouse_id = ? ORDER BY slot_index', { warehouseId })
    
    TriggerClientEvent('sergeis-warehouse:client:receiveStorageContents', src, storage or {})
end)

-- Open warehouse crate storage
RegisterNetEvent('sergeis-warehouse:server:openCrateStorage', function(crateIndex, providedWarehouseId)
    
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    if not player then 
        return 
    end
    
    local citizenId = player.PlayerData.citizenid
    
    -- Debug logging
    print(string.format('[WAREHOUSE DEBUG] Player %s (CitizenID: %s) trying to access crate %s', src, citizenId, crateIndex))
    print(string.format('[WAREHOUSE DEBUG] Provided warehouse ID: %s', providedWarehouseId or 'nil'))
    
    -- Get warehouse ID (either owned or shared)
    local warehouseId = getWarehouseIdForCitizen(citizenId)
    print(string.format('[WAREHOUSE DEBUG] Warehouse ID from getWarehouseIdForCitizen: %s', warehouseId or 'nil'))
    
    -- If provided warehouse ID is given (for shared warehouses), use it
    if providedWarehouseId then
        warehouseId = providedWarehouseId
        print(string.format('[WAREHOUSE DEBUG] Using provided warehouse ID: %s', warehouseId))
    elseif not warehouseId then
        -- Check if player has access to shared warehouses
        local sharedWarehouses = getSharedWarehouses(citizenId)
        print(string.format('[WAREHOUSE DEBUG] Shared warehouses count: %s', #sharedWarehouses))
        if #sharedWarehouses > 0 then
            -- For now, use the first shared warehouse
            -- In the future, you could add a parameter to specify which warehouse
            warehouseId = sharedWarehouses[1].id
            print(string.format('[WAREHOUSE DEBUG] Using shared warehouse ID: %s', warehouseId))
        else
            TriggerClientEvent('QBCore:Notify', src, 'You do not have access to any warehouse', 'error')
            return
        end
    end
    
    print(string.format('[WAREHOUSE DEBUG] Final warehouse ID for storage access: %s', warehouseId))
    
    -- Validate that player is in the correct bucket
    if not validatePlayerBucket(src, warehouseId) then
        TriggerClientEvent('QBCore:Notify', src, 'Access denied: Invalid warehouse session', 'error')
        return
    end
    
    -- Get warehouse data
    local warehouse = MySQL.query.await('SELECT * FROM warehouses WHERE id = ?', { warehouseId })
    print(string.format('[WAREHOUSE DEBUG] Warehouse data found: %s', warehouse and #warehouse > 0 and 'yes' or 'no'))
    if not warehouse or #warehouse == 0 then
        TriggerClientEvent('QBCore:Notify', src, 'Warehouse not found', 'error')
        return
    end
    
    warehouse = warehouse[1]
    print(string.format('[WAREHOUSE DEBUG] Warehouse ID: %s, Owner citizenId: %s, Player citizenId: %s', warehouseId, warehouse.citizenid, citizenId))
    print(string.format('[WAREHOUSE DEBUG] Full warehouse data: %s', json.encode(warehouse)))
    
    -- For warehouse owners, skip permission check (they have full access)
    -- For shared users, check permissions
    local isOwner = (warehouse.citizenid == citizenId)
    
    -- Always log this critical information for troubleshooting
    print(string.format('[WAREHOUSE] CRITICAL DEBUG - Warehouse ID: %s, Owner: %s, Player: %s, IsOwner: %s', 
        warehouseId, warehouse.citizenid, citizenId, isOwner and 'YES' or 'NO'))
    
    if Config.Debug then
        print(string.format('[WAREHOUSE DEBUG] Is owner: %s', isOwner and 'yes' or 'no'))
        print(string.format('[WAREHOUSE DEBUG] Warehouse owner citizenId: %s, Player citizenId: %s', warehouse.citizenid, citizenId))
        print(string.format('[WAREHOUSE DEBUG] Owner comparison result: %s == %s = %s', warehouse.citizenid, citizenId, tostring(warehouse.citizenid == citizenId)))
    end
    
    if not isOwner then
        print(string.format('[WAREHOUSE] SHARED USER ACCESS - Checking permissions for %s in warehouse %s', citizenId, warehouseId))
        
        if Config.Debug then
            print(string.format('[WAREHOUSE DEBUG] Checking shared access for citizenId: %s, warehouseId: %s', citizenId, warehouseId))
        end
        
        -- Add detailed logging for the permission check
        local hasAccess = hasWarehouseAccess(citizenId, warehouseId, 'read')
        print(string.format('[WAREHOUSE] PERMISSION RESULT - hasWarehouseAccess: %s', hasAccess and 'GRANTED' or 'DENIED'))
        
        if Config.Debug then
            print(string.format('[WAREHOUSE DEBUG] hasWarehouseAccess result: %s', hasAccess and 'true' or 'false'))
        end
        
        if not hasAccess then
            print('[WAREHOUSE] ACCESS DENIED - Shared user permission check failed')
            TriggerClientEvent('QBCore:Notify', src, 'You do not have permission to access this warehouse', 'error')
            return
        end
        print('[WAREHOUSE] ACCESS GRANTED - Shared user permission check passed')
    else
        print('[WAREHOUSE] OWNER ACCESS - Skipping permission check')
    end
    
    -- Check if crate is within purchased slots
    if crateIndex > warehouse.purchased_slots then
        TriggerClientEvent('QBCore:Notify', src, 'This storage crate is not available', 'error')
        return
    end
    
    print(string.format('[WAREHOUSE DEBUG] Opening stash for warehouse %s, crate %s', warehouseId, crateIndex))
    
    -- Create unique stash ID for this crate
    local stashId = 'warehouse_crate_' .. warehouseId .. '_' .. crateIndex
    local stashLabel = 'Warehouse Crate ' .. crateIndex
    
    print(string.format('[WAREHOUSE DEBUG] Created stash ID: %s, Label: %s', stashId, stashLabel))
    
    -- Add a small delay to prevent stash creation conflicts when multiple players access simultaneously
    Wait(100)
    
    -- Open the stash using the configured inventory system
    if Config.InventorySystem == 'ox_inventory' and exports.ox_inventory then
        print('[WAREHOUSE DEBUG] ox_inventory export found, proceeding with stash creation')
        
        -- Try to create the stash, but don't fail if it already exists
        print(string.format('[WAREHOUSE DEBUG] Creating stash with - Slots: %s, Weight: %s', 
            Config.Storage.ox_inventory.maxSlots, Config.Storage.ox_inventory.maxWeight))
        
        -- Attempt to create the stash, but continue even if it fails (might already exist)
        local success = false
        local errorMsg = nil
        
        -- Try to create the stash with error handling
        local status, result = pcall(function()
            return exports.ox_inventory:RegisterStash(stashId, stashLabel, Config.Storage.ox_inventory.maxSlots, Config.Storage.ox_inventory.maxWeight)
        end)
        
        if status then
            success = result
            print(string.format('[WAREHOUSE DEBUG] ox_inventory stash creation attempt: %s', success and 'success' or 'failed'))
        else
            errorMsg = tostring(result)
            print(string.format('[WAREHOUSE DEBUG] ox_inventory stash creation error: %s', errorMsg))
        end
        
        -- Even if stash creation "fails", it might just mean it already exists
        -- Try to open the stash anyway
        print('[WAREHOUSE DEBUG] Attempting to open stash for player (existing or new)')
        TriggerClientEvent('ox_inventory:openInventory', src, 'stash', stashId)
        print('[WAREHOUSE DEBUG] ox_inventory:openInventory event triggered')
        
        -- Send a confirmation to the player
        TriggerClientEvent('QBCore:Notify', src, 'Storage opened successfully', 'success')
        
    elseif Config.InventorySystem == 'qb-inventory' and exports['qb-inventory'] then
        
        -- Open the stash using QBCore's stash system
        TriggerClientEvent('inventory:client:SetCurrentStash', src, stashId)
        exports['qb-inventory']:openInventory(src, 'stash', stashId)
        print('[WAREHOUSE DEBUG] qb-inventory stash opened')
        
    else
        
        -- Fallback to ox_inventory if available
        if exports.ox_inventory then
            local success = exports.ox_inventory:RegisterStash(stashId, stashLabel, Config.Storage.ox_inventory.maxSlots, Config.Storage.ox_inventory.maxWeight)
            print(string.format('[WAREHOUSE DEBUG] Fallback ox_inventory stash creation: %s', success and 'success' or 'failed'))
            
            TriggerClientEvent('ox_inventory:openInventory', src, 'stash', stashId)
        else
            TriggerClientEvent('QBCore:Notify', src, 'Inventory system not available', 'error')
        end
    end
    
    print('[WAREHOUSE DEBUG] Storage access function completed successfully')
end)

-- Store item in warehouse
RegisterNetEvent('sergeis-warehouse:server:storeItem', function(slotIndex, itemName, itemCount)
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    if not player then return end
    
    local citizenId = player.PlayerData.citizenid
    local warehouseId = getWarehouseIdForCitizen(citizenId)
    
    if not warehouseId then
        -- Check if player has access to shared warehouses
        local sharedWarehouses = getSharedWarehouses(citizenId)
        if #sharedWarehouses > 0 then
            -- For now, use the first shared warehouse
            warehouseId = sharedWarehouses[1].id
        else
            TriggerClientEvent('QBCore:Notify', src, 'You do not have access to any warehouse', 'error')
            return
        end
    end
    
    -- Validate that player is in the correct bucket
    if not validatePlayerBucket(src, warehouseId) then
        TriggerClientEvent('QBCore:Notify', src, 'Access denied: Invalid warehouse session', 'error')
        return
    end
    
    -- Get warehouse data and check permissions
    local warehouse = MySQL.query.await('SELECT * FROM warehouses WHERE id = ?', { warehouseId })
    if not warehouse or #warehouse == 0 then
        TriggerClientEvent('QBCore:Notify', src, 'Warehouse not found', 'error')
        return
    end
    
    warehouse = warehouse[1]
    
    -- Check if player has write access to this warehouse
    if not hasWarehouseAccess(citizenId, warehouseId, 'write') then
        TriggerClientEvent('QBCore:Notify', src, 'You do not have permission to store items in this warehouse', 'error')
        return
    end
    
    -- Check if slot is available (within purchased slots)
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
        -- Check if player has access to shared warehouses
        local sharedWarehouses = getSharedWarehouses(citizenId)
        if #sharedWarehouses > 0 then
            -- For now, use the first shared warehouse
            warehouseId = sharedWarehouses[1].id
        else
            TriggerClientEvent('QBCore:Notify', src, 'You do not have access to any warehouse', 'error')
            return
        end
    end
    
    -- Validate that player is in the correct bucket
    if not validatePlayerBucket(src, warehouseId) then
        TriggerClientEvent('QBCore:Notify', src, 'Access denied: Invalid warehouse session', 'error')
        return
    end
    
    -- Get warehouse data and check permissions
    local warehouse = MySQL.query.await('SELECT * FROM warehouses WHERE id = ?', { warehouseId })
    if not warehouse or #warehouse == 0 then
        TriggerClientEvent('QBCore:Notify', src, 'Warehouse not found', 'error')
        return
    end
    
    warehouse = warehouse[1]
    
    -- For warehouse owners, skip permission check (they have full access)
    -- For shared users, check permissions
    local isOwner = (warehouse.citizenid == citizenId)
    if not isOwner then
        if not hasWarehouseAccess(citizenId, warehouseId, 'write') then
            TriggerClientEvent('QBCore:Notify', src, 'You do not have permission to store items in this warehouse', 'error')
            return
        end
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

-- ========================================
-- WAREHOUSE SHARING SYSTEM FUNCTIONS
-- ========================================

-- Get warehouses shared with a player
local function getSharedWarehouses(citizenId)
    local result = MySQL.query.await([[
        SELECT w.*, ws.permission_level, ws.created_at as shared_at, ws.expires_at,
               JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.firstname')) as owner_firstname, 
               JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.lastname')) as owner_lastname
        FROM warehouse_sharing ws
        JOIN warehouses w ON ws.warehouse_id = w.id
        LEFT JOIN players p ON ws.owner_citizenid = p.citizenid
        WHERE ws.shared_with_citizenid = ? AND (ws.expires_at > NOW() OR ws.expires_at IS NULL)
        ORDER BY ws.created_at DESC
    ]], { citizenId })
    
    return result or {}
end

-- Get players with access to a warehouse
local function getWarehouseSharedUsers(warehouseId)
    local result = MySQL.query.await([[
        SELECT ws.*, 
               JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.firstname')) as player_firstname, 
               JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.lastname')) as player_lastname
        FROM warehouse_sharing ws
        LEFT JOIN players p ON ws.shared_with_citizenid = p.citizenid
        WHERE ws.warehouse_id = ?
        ORDER BY ws.created_at DESC
    ]], { warehouseId })
    
    return result or {}
end

-- Share warehouse with player
RegisterNetEvent('sergeis-warehouse:server:shareWarehouse', function(targetCitizenId, permissionLevel, expiresAt)
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    if not player then return end
    
    local citizenId = player.PlayerData.citizenid
    local warehouseId = getWarehouseIdForCitizen(citizenId)
    
    if not warehouseId then
        TriggerClientEvent('QBCore:Notify', src, 'You do not own a warehouse', 'error')
        return
    end
    
    -- Validate permission level
    local validPermissions = Config.Sharing.permissionLevels
    if not table.contains(validPermissions, permissionLevel) then
        TriggerClientEvent('QBCore:Notify', src, 'Invalid permission level', 'error')
        return
    end
    
    -- Check if trying to share with self
    if targetCitizenId == citizenId then
        TriggerClientEvent('QBCore:Notify', src, 'You cannot share with yourself', 'error')
        return
    end
    
    -- Check if already shared
    local existingShare = MySQL.query.await('SELECT * FROM warehouse_sharing WHERE warehouse_id = ? AND shared_with_citizenid = ?', {
        warehouseId, targetCitizenId
    })
    
    if existingShare and #existingShare > 0 then
        TriggerClientEvent('QBCore:Notify', src, 'Warehouse already shared with this player', 'error')
        return
    end
    
    -- Check max shared users limit
    local currentShares = MySQL.query.await('SELECT COUNT(*) as count FROM warehouse_sharing WHERE warehouse_id = ?', { warehouseId })
    if currentShares and currentShares[1].count >= Config.Sharing.maxSharedUsers then
        TriggerClientEvent('QBCore:Notify', src, 'Maximum shared users limit reached', 'error')
        return
    end
    
    -- Insert sharing record
    local success = MySQL.insert.await('INSERT INTO warehouse_sharing (warehouse_id, owner_citizenid, shared_with_citizenid, permission_level, expires_at) VALUES (?, ?, ?, ?, ?)', {
        warehouseId, citizenId, targetCitizenId, permissionLevel, expiresAt
    })
    
    if success then
        TriggerClientEvent('QBCore:Notify', src, 'Warehouse shared successfully', 'success')
        TriggerClientEvent('sergeis-warehouse:client:refreshSharing', src)
        
        -- Log access
        MySQL.insert.await('INSERT INTO warehouse_access_log (warehouse_id, player_citizenid, action) VALUES (?, ?, ?)', {
            warehouseId, targetCitizenId, 'access_granted'
        })
    else
        TriggerClientEvent('QBCore:Notify', src, 'Failed to share warehouse', 'error')
    end
end)

-- Revoke sharing access
RegisterNetEvent('sergeis-warehouse:server:revokeAccess', function(targetCitizenId)
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    if not player then return end
    
    local citizenId = player.PlayerData.citizenid
    local warehouseId = getWarehouseIdForCitizen(citizenId)
    
    if not warehouseId then
        TriggerClientEvent('QBCore:Notify', src, 'You do not own a warehouse', 'error')
        return
    end
    
    -- Delete sharing record
    local success = MySQL.query.await('DELETE FROM warehouse_sharing WHERE warehouse_id = ? AND shared_with_citizenid = ?', {
        warehouseId, targetCitizenId
    })
    
    if success then
        TriggerClientEvent('QBCore:Notify', src, 'Access revoked successfully', 'success')
        TriggerClientEvent('sergeis-warehouse:client:refreshSharing', src)
        
        -- Log access
        MySQL.insert.await('INSERT INTO warehouse_access_log (warehouse_id, player_citizenid, action) VALUES (?, ?, ?)', {
            warehouseId, targetCitizenId, 'access_revoked'
        })
    else
        TriggerClientEvent('QBCore:Notify', src, 'Failed to revoke access', 'error')
    end
end)

-- Update sharing permissions
RegisterNetEvent('sergeis-warehouse:server:updateSharingPermissions', function(targetCitizenId, newPermissionLevel)
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    if not player then return end
    
    local citizenId = player.PlayerData.citizenid
    local warehouseId = getWarehouseIdForCitizen(citizenId)
    
    if not warehouseId then
        TriggerClientEvent('QBCore:Notify', src, 'You do not own a warehouse', 'error')
        return
    end
    
    -- Validate permission level
    local validPermissions = Config.Sharing.permissionLevels
    if not table.contains(validPermissions, newPermissionLevel) then
        TriggerClientEvent('QBCore:Notify', src, 'Invalid permission level', 'error')
        return
    end
    
    -- Update sharing record
    local success = MySQL.update.await('UPDATE warehouse_sharing SET permission_level = ? WHERE warehouse_id = ? AND shared_with_citizenid = ?', {
        newPermissionLevel, warehouseId, targetCitizenId
    })
    
    if success then
        TriggerClientEvent('QBCore:Notify', src, 'Permissions updated successfully', 'success')
        TriggerClientEvent('sergeis-warehouse:client:refreshSharing', src)
        
        -- Log access
        MySQL.insert.await('INSERT INTO warehouse_access_log (warehouse_id, player_citizenid, action) VALUES (?, ?, ?)', {
            warehouseId, targetCitizenId, 'permissions_updated'
        })
    else
        TriggerClientEvent('QBCore:Notify', src, 'Failed to update permissions', 'error')
    end
end)

-- Update warehouse sharing permissions
RegisterNetEvent('sergeis-warehouse:server:updateWarehouseSharing', function(targetCitizenId, newPermission, newExpiresAt)
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    if not player then return end
    
    local citizenId = player.PlayerData.citizenid
    local warehouseId = getWarehouseIdForCitizen(citizenId)
    
    if not warehouseId then
        TriggerClientEvent('QBCore:Notify', src, 'You do not own a warehouse', 'error')
        return
    end
    
    -- Validate permission level
    local validPermissions = Config.Sharing.permissionLevels
    if not table.contains(validPermissions, newPermission) then
        TriggerClientEvent('QBCore:Notify', src, 'Invalid permission level', 'error')
        return
    end
    
    -- Check if trying to update self
    if targetCitizenId == citizenId then
        TriggerClientEvent('QBCore:Notify', src, 'You cannot modify your own access', 'error')
        return
    end
    
    -- Check if sharing exists
    local existingShare = MySQL.query.await('SELECT * FROM warehouse_sharing WHERE warehouse_id = ? AND shared_with_citizenid = ?', {
        warehouseId, targetCitizenId
    })
    
    if not existingShare or #existingShare == 0 then
        TriggerClientEvent('QBCore:Notify', src, 'No sharing record found for this player', 'error')
        return
    end
    
    -- Update the sharing record
    local success = MySQL.update.await('UPDATE warehouse_sharing SET permission_level = ?, expires_at = ? WHERE warehouse_id = ? AND shared_with_citizenid = ?', {
        newPermission, newExpiresAt or nil, warehouseId, targetCitizenId
    })
    
    if success then
        TriggerClientEvent('QBCore:Notify', src, 'Sharing permissions updated successfully', 'success')
        
        -- Log the update
        MySQL.insert.await('INSERT INTO warehouse_access_log (warehouse_id, player_citizenid, action) VALUES (?, ?, ?)', {
            warehouseId, targetCitizenId, 'permissions_updated'
        })
        
        -- Refresh warehouse info for the owner
        TriggerEvent('sergeis-warehouse:server:getWarehouseInfo', src)
    else
        TriggerClientEvent('QBCore:Notify', src, 'Failed to update sharing permissions', 'error')
    end
end)

-- Revoke warehouse sharing access
RegisterNetEvent('sergeis-warehouse:server:revokeWarehouseSharing', function(targetCitizenId)
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    if not player then return end
    
    local citizenId = player.PlayerData.citizenid
    local warehouseId = getWarehouseIdForCitizen(citizenId)
    
    if not warehouseId then
        TriggerClientEvent('QBCore:Notify', src, 'You do not own a warehouse', 'error')
        return
    end
    
    -- Check if trying to revoke self
    if targetCitizenId == citizenId then
        TriggerClientEvent('QBCore:Notify', src, 'You cannot revoke your own access', 'error')
        return
    end
    
    -- Check if sharing exists
    local existingShare = MySQL.query.await('SELECT * FROM warehouse_sharing WHERE warehouse_id = ? AND shared_with_citizenid = ?', {
        warehouseId, targetCitizenId
    })
    
    if not existingShare or #existingShare == 0 then
        TriggerClientEvent('QBCore:Notify', src, 'No sharing record found for this player', 'error')
        return
    end
    
    -- Remove the sharing record
    local success = MySQL.query.await('DELETE FROM warehouse_sharing WHERE warehouse_id = ? AND shared_with_citizenid = ?', {
        warehouseId, targetCitizenId
    })
    
    if success then
        TriggerClientEvent('QBCore:Notify', src, 'Access revoked successfully', 'success')
        
        -- Log the revocation
        MySQL.insert.await('INSERT INTO warehouse_access_log (warehouse_id, player_citizenid, action) VALUES (?, ?, ?)', {
            warehouseId, targetCitizenId, 'access_revoked'
        })
        
        -- Refresh warehouse info for the owner
        TriggerEvent('sergeis-warehouse:server:getWarehouseInfo', src)
    else
        TriggerClientEvent('QBCore:Notify', src, 'Failed to revoke access', 'error')
    end
end)

-- Get warehouse info for UI (updated to include sharing)
RegisterNetEvent('sergeis-warehouse:server:getWarehouseInfo', function()
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    if not player then 
        print(string.format('[WAREHOUSE] getWarehouseInfo: Player not found for source %s, retrying in 2 seconds...', src))
        -- Retry after a short delay if player is not loaded yet
        CreateThread(function()
            Wait(2000)
            local retryPlayer = QBCore.Functions.GetPlayer(src)
            if retryPlayer then
                print(string.format('[WAREHOUSE] getWarehouseInfo: Retry successful for source %s', src))
                TriggerEvent('sergeis-warehouse:server:getWarehouseInfo', src)
            else
                print(string.format('[WAREHOUSE] getWarehouseInfo: Retry failed for source %s', src))
            end
        end)
        return 
    end
    
    local citizenId = player.PlayerData.citizenid
    local warehouse = getWarehouseData(citizenId)
    
    if warehouse then
        -- Get shared users
        local sharedUsers = getWarehouseSharedUsers(warehouse.id)
        
        local info = {
            owned = true,
            id = warehouse.id,
            purchased_slots = warehouse.purchased_slots,
            max_slots = Config.Warehouse.maxSlots,
            slot_price = Config.Warehouse.slotPrice,
            slot_prices = Config.Warehouse.slotPrices,
            sell_price = Config.Warehouse.sellPrice,
            shared_users = sharedUsers
        }
        
        TriggerClientEvent('sergeis-warehouse:client:updateWarehouseInfo', src, info)
    else
        -- Check if player has access to shared warehouses
        local sharedWarehouses = getSharedWarehouses(citizenId)
        
        local info = {
            owned = false,
            shared_warehouses = sharedWarehouses
        }
        
        TriggerClientEvent('sergeis-warehouse:client:updateWarehouseInfo', src, info)
    end
end)

-- Get shared warehouses for UI
RegisterNetEvent('sergeis-warehouse:server:getSharedWarehouses', function()
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    if not player then return end
    
    local citizenId = player.PlayerData.citizenid
    local sharedWarehouses = getSharedWarehouses(citizenId)
    
    TriggerClientEvent('sergeis-warehouse:client:updateSharedWarehouses', src, sharedWarehouses)
end)

-- Helper function to check if table contains value
function table.contains(table, element)
    for _, value in pairs(table) do
        if value == element then
            return true
        end
    end
    return false
end

-- Enter shared warehouse
RegisterNetEvent('sergeis-warehouse:server:enterSharedWarehouse', function(warehouseId)
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    if not player then return end
    
    local citizenId = player.PlayerData.citizenid
    
    print("^2[WAREHOUSE] Player " .. citizenId .. " attempting to enter shared warehouse " .. warehouseId .. "^7")
    
    -- Check if player has access to this warehouse
    if not hasWarehouseAccess(citizenId, warehouseId, 'read') then
        print("^1[WAREHOUSE] Access denied for " .. citizenId .. " to warehouse " .. warehouseId .. "^7")
        TriggerClientEvent('QBCore:Notify', src, 'Access denied to this warehouse', 'error')
        return
    end
    
    print("^2[WAREHOUSE] Access granted for " .. citizenId .. " to warehouse " .. warehouseId .. "^7")
    
    -- Use warehouse-based bucket so all players in the same warehouse can see each other
    SetPlayerRoutingBucket(src, warehouseId)
    
    -- Store bucket info for the player (using warehouse-based buckets)
    playerWarehouseBuckets[src] = warehouseId
    Player(src).state.warehouseBucket = warehouseId
    Player(src).state.warehouseId = warehouseId
    
    print(string.format('[WAREHOUSE] Shared warehouse: Player %s (%s) entered warehouse %s bucket %d (shared bucket)', 
        player.PlayerData.name, citizenId, warehouseId, warehouseId))
    
    -- Log access
    MySQL.insert.await('INSERT INTO warehouse_access_log (warehouse_id, player_citizenid, action) VALUES (?, ?, ?)', {
        warehouseId, citizenId, 'warehouse_entered'
    })
    
    -- Teleport player to warehouse interior
    local interiorCoords = Config.Warehouse.interiorAnchor
    print("^2[WAREHOUSE] Teleporting " .. citizenId .. " to warehouse interior at " .. tostring(interiorCoords) .. "^7")
    
    -- Send teleport command to client
    TriggerClientEvent('sergeis-warehouse:client:teleportToInterior', src, interiorCoords)
    
    TriggerClientEvent('QBCore:Notify', src, 'Welcome to the shared warehouse', 'success')
end)

-- Exit warehouse (for both owned and shared)
RegisterNetEvent('sergeis-warehouse:server:exitWarehouse', function()
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    if not player then return end
    
    local citizenId = player.PlayerData.citizenid
    local currentBucket = playerWarehouseBuckets[src]
    
    print(string.format('[WAREHOUSE] Player %s (%s) exiting warehouse from bucket %s', 
        player.PlayerData.name, citizenId, currentBucket or 'none'))
    
    -- Reset player's routing bucket
    if currentBucket and currentBucket > 0 then
        SetPlayerRoutingBucket(src, 0)
        playerWarehouseBuckets[src] = nil
        
        -- Clear player state
        if Player(src).state.warehouseBucket then
            Player(src).state.warehouseBucket = nil
        end
        if Player(src).state.warehouseId then
            Player(src).state.warehouseId = nil
        end
        
        print(string.format('[WAREHOUSE] Player %s (%s) returned to default bucket from warehouse bucket %d', 
            player.PlayerData.name, citizenId, currentBucket))
        
        -- Log exit
        MySQL.insert.await('INSERT INTO warehouse_access_log (warehouse_id, player_citizenid, action) VALUES (?, ?, ?)', {
            currentBucket, citizenId, 'warehouse_exited'
        })
    end
    
    -- Notify client that exit is complete
    TriggerClientEvent('sergeis-warehouse:client:warehouseExitComplete', src)
end)

-- Get shared warehouse info for crate spawning
RegisterNetEvent('sergeis-warehouse:server:getSharedWarehouseInfo', function(warehouseId)
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    if not player then return end
    
    local citizenId = player.PlayerData.citizenid
    
    print("^2[WAREHOUSE] Player " .. citizenId .. " requesting info for shared warehouse " .. warehouseId .. "^7")
    
    -- Check if player has access to this warehouse
    if not hasWarehouseAccess(citizenId, warehouseId, 'read') then
        print("^1[WAREHOUSE] Access denied for " .. citizenId .. " to warehouse " .. warehouseId .. "^7")
        return
    end
    
    -- Get warehouse info
    local result = MySQL.single.await('SELECT * FROM warehouses WHERE id = ?', {warehouseId})
    if result then
        print("^2[WAREHOUSE] Sending shared warehouse info to " .. citizenId .. ": " .. result.purchased_slots .. " slots^7")
        
        -- Send warehouse info to client
        TriggerClientEvent('sergeis-warehouse:client:receiveSharedWarehouseInfo', src, {
            id = result.id,
            purchased_slots = result.purchased_slots,
            max_slots = Config.Warehouse.maxSlots
        })
    else
        print("^1[WAREHOUSE] Warehouse " .. warehouseId .. " not found^7")
    end
end)

-- Load nearby players
RegisterNetEvent('sergeis-warehouse:server:loadNearbyPlayers', function()
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    if not player then 
        print("^1[WAREHOUSE] loadNearbyPlayers: Player not found for source " .. src .. "^7")
        return 
    end
    
    local players = {}
    local playerCoords = GetEntityCoords(GetPlayerPed(src))
    
    print("^2[WAREHOUSE] loadNearbyPlayers: Source " .. src .. " at coords " .. tostring(playerCoords) .. "^7")
    
    -- Get all players in the server
    local allPlayers = QBCore.Functions.GetPlayers()
    print("^2[WAREHOUSE] loadNearbyPlayers: Found " .. #allPlayers .. " total players^7")
    
    for _, playerId in pairs(allPlayers) do
        if playerId ~= src then -- Exclude self
            local targetPlayer = QBCore.Functions.GetPlayer(playerId)
            if targetPlayer then
                local targetCoords = GetEntityCoords(GetPlayerPed(playerId))
                local distance = #(playerCoords - targetCoords)
                
                print("^3[WAREHOUSE] loadNearbyPlayers: Player " .. playerId .. " at distance " .. distance .. "m^7")
                
                -- Only include players within 50 meters
                if distance <= 50.0 then
                    local playerName = GetPlayerName(playerId)
                    local firstName, lastName
                    
                    -- Handle both single-word and multi-word names
                    if string.find(playerName, "%s") then
                        -- Multi-word name: "FirstName LastName"
                        firstName, lastName = string.match(playerName, "(%S+)%s+(.+)")
                    else
                        -- Single-word name: "Name"
                        firstName = playerName
                        lastName = "" -- Empty last name for single-word names
                    end
                    
                    print("^2[WAREHOUSE] loadNearbyPlayers: Nearby player " .. playerName .. " (distance: " .. distance .. "m)^7")
                    print("^2[WAREHOUSE] Parsed name - First: '" .. tostring(firstName) .. "', Last: '" .. tostring(lastName) .. "'^7")
                    
                    -- Include all nearby players (no search filtering)
                    if firstName then
                        table.insert(players, {
                            id = playerId,
                            firstname = firstName,
                            lastname = lastName or "",
                            citizenid = targetPlayer.PlayerData.citizenid,
                            distance = math.floor(distance)
                        })
                        print("^2[WAREHOUSE] loadNearbyPlayers: Added player " .. firstName .. (lastName and " " .. lastName or "") .. "^7")
                    else
                        print("^1[WAREHOUSE] loadNearbyPlayers: Failed to parse name for player " .. playerName .. "^7")
                    end
                end
            else
                print("^1[WAREHOUSE] loadNearbyPlayers: Target player " .. playerId .. " not found^7")
            end
        end
    end
    
    -- Sort by distance
    table.sort(players, function(a, b) return a.distance < b.distance end)
    
    print("^2[WAREHOUSE] loadNearbyPlayers: Sending " .. #players .. " nearby players to client^7")
    
    -- Send results back to client
    TriggerClientEvent('sergeis-warehouse:client:nearbyPlayersResults', src, players)
end)



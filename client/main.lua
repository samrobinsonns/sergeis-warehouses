local QBCore = exports['qb-core']:GetCoreObject()

-- Variables
local ownership = { has = false, id = nil, purchased_slots = 0 }
local currentAnchor = nil
local currentAnchorHeading = 0.0
local currentLoadedIPLs = nil
local currentBucket = nil
local insideWarehouse = false
local currentWarehouseId = nil -- Track which warehouse player is currently in (for shared warehouses)
local salesPedId = nil
local entranceBlip = nil
local entranceDoor = nil
local interiorProps = {}
local shelvedProps = {}

-- Function to add target integration for crates
local function addCrateTarget(crate, crateIndex)
    if not crate or not DoesEntityExist(crate) then 
        return 
    end
    
    if Config.TargetSystem == 'qb-target' and exports['qb-target'] then
        exports['qb-target']:AddTargetEntity(crate, {
            options = {
                {
                    label = 'Open Storage',
                    icon = 'fas fa-box-open',
                    action = function()
                        openCrateStorage(crateIndex)
                    end
                }
            },
            distance = 2.0
        })
    elseif Config.TargetSystem == 'ox_target' and exports.ox_target then
        exports.ox_target:addLocalEntity(crate, {
            {
                name = 'warehouse_crate_' .. crateIndex,
                label = 'Open Storage',
                icon = 'fa-solid fa-box-open',
                onSelect = function()
                    openCrateStorage(crateIndex)
                end
            }
        })
    end
end

-- Function to open crate storage
function openCrateStorage(crateIndex)
    
    print("^2[WAREHOUSE] openCrateStorage called with crateIndex: " .. crateIndex .. "^7")
    print("^2[WAREHOUSE] ownership.has: " .. tostring(ownership.has) .. "^7")
    print("^2[WAREHOUSE] ownership.id: " .. tostring(ownership.id) .. "^7")
    
    -- Check if player has access to warehouse (either owned or shared)
    if not ownership.has and not ownership.id then
        print("^1[WAREHOUSE] Access denied: No warehouse access^7")
        QBCore.Functions.Notify('You do not have access to any warehouse', 'error')
        return
    end
    
    -- For owned warehouses, check purchased slots
    if ownership.has then
        if crateIndex > ownership.purchased_slots then
            print("^1[WAREHOUSE] Access denied: Crate not available for owned warehouse^7")
            QBCore.Functions.Notify('This storage crate is not available', 'error')
            return
        end
        print("^2[WAREHOUSE] Access granted: Owned warehouse^7")
    else
        print("^2[WAREHOUSE] Access granted: Shared warehouse^7")
    end
    
    -- For shared warehouses, the server will validate access and slot availability
    -- Just trigger the server event and let it handle the validation
    
    -- Trigger server event to open storage
    print("^2[WAREHOUSE] Triggering server event: openCrateStorage^7")
    
    -- For shared warehouses, send the current warehouse ID
    if not ownership.has and currentWarehouseId then
        print("^2[WAREHOUSE] Sending shared warehouse ID: " .. currentWarehouseId .. "^7")
        TriggerServerEvent('sergeis-warehouse:server:openCrateStorage', crateIndex, currentWarehouseId)
    else
        -- For owned warehouses, just send crate index (server will use ownership.id)
        print("^2[WAREHOUSE] Sending owned warehouse request (server will use ownership.id: " .. tostring(ownership.id) .. ")^7")
        TriggerServerEvent('sergeis-warehouse:server:openCrateStorage', crateIndex)
    end
    
end

local function requestModel(model)
    local hash = type(model) == 'number' and model or joaat(model)
    if not IsModelInCdimage(hash) then return nil end
    RequestModel(hash)
    while not HasModelLoaded(hash) do Wait(0) end
    return hash
end

local function createPed(model, coords, scenario)
    local hash = requestModel(model)
    if not hash then return nil end
    local ped = CreatePed(4, hash, coords.x, coords.y, coords.z - 1.0, coords.w or 0.0, false, true)
    SetEntityAsMissionEntity(ped, true, true)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    if scenario then TaskStartScenarioInPlace(ped, scenario, 0, true) end
    return ped
end

local function draw3DText(coords, text)
    SetDrawOrigin(coords.x, coords.y, coords.z, 0)
    SetTextScale(0.35, 0.35)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 215)
    SetTextCentre(true)
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(0.0, 0.0)
    ClearDrawOrigin()
end



local function createBlip(coords, cfg)
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, cfg.sprite)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, cfg.scale)
    SetBlipColour(blip, cfg.color)
    SetBlipAsShortRange(blip, cfg.shortRange ~= false)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(cfg.text)
    EndTextCommandSetBlipName(blip)
    return blip
end

local function teleportWithCollision(ped, coords, heading)
    local playerId = PlayerId()
    SetFocusPosAndVel(coords.x, coords.y, coords.z, 0.0, 0.0, 0.0)
    StartPlayerTeleport(playerId, coords.x, coords.y, coords.z + 0.2, heading or GetEntityHeading(ped), true, true, true)
    local timeout = GetGameTimer() + 8000
    while IsPlayerTeleportActive() and GetGameTimer() < timeout do
        Wait(0)
    end
    SetEntityCoordsNoOffset(ped, coords.x, coords.y, coords.z, false, false, false)
    if heading then SetEntityHeading(ped, heading) end
    ClearFocus()
    FreezeEntityPosition(ped, true)
    local holdUntil = GetGameTimer() + 2000
    while GetGameTimer() < holdUntil do
        local height = GetEntityHeightAboveGround(ped)
        if height >= 0.0 and height < 0.6 and not IsEntityInAir(ped) and not IsPedFalling(ped) then
            break
        end
        if coords then RequestCollisionAtCoord(coords.x, coords.y, coords.z) end
        Wait(0)
    end
    FreezeEntityPosition(ped, false)
end

local function waitForInteriorReady(maxWaitMs)
    local deadline = GetGameTimer() + (maxWaitMs or 1500)
    while GetGameTimer() < deadline do
        local allReady = true
        for _, obj in ipairs(interiorProps) do
            if not DoesEntityExist(obj) or not HasCollisionLoadedAroundEntity(obj) then
                allReady = false
                break
            end
        end
        if allReady then break end
        Wait(50)
    end
end

local function loadIPLs(iplList)
    if not iplList or #iplList == 0 then return end
    for _, ipl in ipairs(iplList) do
        if not IsIplActive(ipl) then
            RequestIpl(ipl)
        end
    end
end

local function unloadIPLs(iplList)
    if not iplList or #iplList == 0 then return end
    for _, ipl in ipairs(iplList) do
        if IsIplActive(ipl) then
            RemoveIpl(ipl)
        end
    end
end

local function spawnCrates()
    if not Config.Warehouse or not Config.Warehouse.crates then 
        print('[WAREHOUSE] Cannot spawn crates: Config.Warehouse.crates is nil')
        return 
    end
    
    -- Safety check: only spawn crates if we have a valid anchor
    if not currentAnchor then
        print('[WAREHOUSE] Cannot spawn crates: currentAnchor is nil')
        return
    end
    
    -- Clear existing crates first
    for _, crate in ipairs(shelvedProps) do
        if DoesEntityExist(crate) then
            DeleteEntity(crate)
        end
    end
    shelvedProps = {}
    
    -- Determine how many slots to spawn based on warehouse type
    local slotsToSpawn = 0
    if ownership.has then
        -- Owned warehouse: use purchased slots
        slotsToSpawn = ownership.purchased_slots or 0
        print('[WAREHOUSE] Spawning crates for owned warehouse with ' .. slotsToSpawn .. ' slots')
    else
        -- Shared warehouse: get warehouse info from server
        if ownership.id then
            print('[WAREHOUSE] Spawning crates for shared warehouse ' .. ownership.id .. ' - requesting slot count from server')
            -- Request warehouse info from server to get slot count
            TriggerServerEvent('sergeis-warehouse:server:getSharedWarehouseInfo', ownership.id)
            return -- Exit early, will be called again when server responds
        else
            print('[WAREHOUSE] Cannot spawn crates: no warehouse ID for shared warehouse')
            return
        end
    end
    
    for i = 1, slotsToSpawn do
        if i <= #Config.Warehouse.crates and Config.Warehouse.crates[i] then
            local crateCfg = Config.Warehouse.crates[i]
            
            -- Safety check: ensure crateCfg is valid
            if not crateCfg or not crateCfg.model or not crateCfg.offset then
                print(string.format('[WAREHOUSE] Cannot spawn crate %d: invalid configuration', i))
                goto continue
            end
            
            local hash = requestModel(crateCfg.model)
            if hash then
                -- Safety check: ensure offset coordinates are valid
                local offsetX = crateCfg.offset and crateCfg.offset.x or 0.0
                local offsetY = crateCfg.offset and crateCfg.offset.y or 0.0
                local offsetZ = crateCfg.offset and crateCfg.offset.z or 0.0
                
                local crate = CreateObject(hash, 
                    currentAnchor.x + offsetX, 
                    currentAnchor.y + offsetY, 
                    currentAnchor.z + offsetZ, 
                    false, false, false)
                
                if DoesEntityExist(crate) then
                    -- Safety check for currentAnchorHeading and crateCfg.heading
                    local crateHeading = crateCfg.heading or 0.0
                    local heading = currentAnchorHeading and (currentAnchorHeading + crateHeading) or crateHeading
                    SetEntityHeading(crate, heading)
                    FreezeEntityPosition(crate, true)
                    SetEntityAsMissionEntity(crate, true, true)
                    table.insert(shelvedProps, crate)
                    
                    -- Add target integration for the crate
                    addCrateTarget(crate, i)
                end
            end
            ::continue::
        end
    end
    
end

local function cleanupInterior()
    for _, obj in ipairs(interiorProps) do
        if DoesEntityExist(obj) then
            DeleteEntity(obj)
        end
    end
    interiorProps = {}
    
    for _, obj in ipairs(shelvedProps) do
        if DoesEntityExist(obj) then
            DeleteEntity(obj)
        end
    end
    shelvedProps = {}
    
    if currentLoadedIPLs then
        unloadIPLs(currentLoadedIPLs)
        currentLoadedIPLs = nil
    end
end

-- Function to spawn crates with a specific slot count (for shared warehouses)
local function spawnCratesWithSlots(slotCount)
    if not Config.Warehouse or not Config.Warehouse.crates then 
        print('[WAREHOUSE] Cannot spawn crates: Config.Warehouse.crates is nil')
        return 
    end
    
    -- Safety check: only spawn crates if we have a valid anchor
    if not currentAnchor then
        print('[WAREHOUSE] Cannot spawn crates: currentAnchor is nil')
        return
    end
    
    print('[WAREHOUSE] Spawning ' .. slotCount .. ' crates for shared warehouse')
    
    -- Clear existing crates first
    for _, crate in ipairs(shelvedProps) do
        if DoesEntityExist(crate) then
            DeleteEntity(crate)
        end
    end
    shelvedProps = {}
    
    -- Spawn crates for the specified number of slots
    for i = 1, slotCount do
        if i <= #Config.Warehouse.crates and Config.Warehouse.crates[i] then
            local crateCfg = Config.Warehouse.crates[i]
            
            -- Safety check: ensure crateCfg is valid
            if not crateCfg or not crateCfg.model or not crateCfg.offset then
                print(string.format('[WAREHOUSE] Cannot spawn crate %d: invalid configuration', i))
                goto continue
            end
            
            local hash = requestModel(crateCfg.model)
            if hash then
                -- Safety check: ensure offset coordinates are valid
                local offsetX = crateCfg.offset and crateCfg.offset.x or 0.0
                local offsetY = crateCfg.offset and crateCfg.offset.y or 0.0
                local offsetZ = crateCfg.offset and crateCfg.offset.z or 0.0
                
                local crate = CreateObject(hash, 
                    currentAnchor.x + offsetX, 
                    currentAnchor.y + offsetY, 
                    currentAnchor.z + offsetZ, 
                    false, false, false)
                
                if DoesEntityExist(crate) then
                    -- Safety check for currentAnchorHeading and crateCfg.heading
                    local crateHeading = crateCfg.heading or 0.0
                    local heading = currentAnchorHeading and (currentAnchorHeading + crateHeading) or crateHeading
                    SetEntityHeading(crate, heading)
                    FreezeEntityPosition(crate, true)
                    SetEntityAsMissionEntity(crate, true, true)
                    table.insert(shelvedProps, crate)
                    
                    -- Add target integration for the crate
                    addCrateTarget(crate, i)
                    
                    print('[WAREHOUSE] Successfully spawned crate ' .. i .. ' for shared warehouse')
                end
            end
            ::continue::
        end
    end
    
    print('[WAREHOUSE] Finished spawning ' .. slotCount .. ' crates for shared warehouse')
end

local function enterWarehouse()
    if not ownership.has then
        QBCore.Functions.Notify('You do not own a warehouse', 'error')
        return
    end
    
    local warehouseCfg = Config.Warehouse
    if not warehouseCfg or not warehouseCfg.interiorAnchor then
        QBCore.Functions.Notify('Warehouse configuration error: missing interior anchor configuration', 'error')
        return
    end
    
    currentAnchor = warehouseCfg.interiorAnchor
    
    -- Safety check: ensure currentAnchor is valid
    if not currentAnchor then
        QBCore.Functions.Notify('Warehouse configuration error: invalid interior anchor', 'error')
        return
    end
    
    currentAnchorHeading = currentAnchor.w or 0.0
    currentLoadedIPLs = warehouseCfg.ipls
    
    -- Load IPLs
    loadIPLs(currentLoadedIPLs)
    
    -- Create routing bucket - ensure we have a valid ID
    if not ownership.id or ownership.id <= 0 then
        QBCore.Functions.Notify('Warehouse ID is invalid', 'error')
        return
    end
    
    -- Use warehouse-based bucket for consistency with shared warehouses
    currentBucket = ownership.id
    TriggerServerEvent('sergeis-warehouse:server:setBucket', ownership.id)
    
    print("^2[WAREHOUSE] Owner entering warehouse with bucket ID: " .. currentBucket .. "^7")
    
    -- Wait a moment for the bucket to be set
    Wait(500)
    
    -- Teleport to interior
    local playerPed = PlayerPedId()
    if currentAnchor then
        teleportWithCollision(playerPed, vector3(currentAnchor.x, currentAnchor.y, currentAnchor.z), currentAnchorHeading)
    else
        QBCore.Functions.Notify('Warehouse configuration error: cannot teleport to interior', 'error')
        return
    end
    
    -- Wait for teleport to complete
    Wait(1000)
    
    -- Spawn crates based on current slot count
    spawnCrates()
    
    insideWarehouse = true
    
    -- Debug info
    if Config.Debug then
        print(string.format('[WAREHOUSE] Entered warehouse with bucket ID: %d', currentBucket))
    end
end

local function exitWarehouse()
    if not insideWarehouse then return end
    
    -- Clean up interior
    cleanupInterior()
    
    -- Notify server about warehouse exit
    TriggerServerEvent('sergeis-warehouse:server:exitWarehouse')
    
    -- Reset routing bucket locally
    if currentBucket then
        currentBucket = nil
    end
    
    -- Teleport to entrance
    local playerPed = PlayerPedId()
    local exitCoords = Config.Entrance.coords
    teleportWithCollision(playerPed, exitCoords, Config.Entrance.heading)
    
    -- Reset warehouse state
    insideWarehouse = false
    currentWarehouseId = nil
    
    -- If this was a shared warehouse, reset the ownership state properly
    if not ownership.has and ownership.id then
        print('[WAREHOUSE] Exiting shared warehouse, resetting ownership state')
        resetSharedWarehouseState()
    end
    
    print('[WAREHOUSE] Warehouse exit completed - insideWarehouse:', insideWarehouse, 'currentWarehouseId:', currentWarehouseId, 'ownership.id:', ownership.id)
end

local function refreshOwnership()
    TriggerServerEvent('sergeis-warehouse:server:getWarehouseInfo')
end

-- Event handlers
RegisterNetEvent('sergeis-warehouse:client:receiveWarehouseInfo', function(info)
    
    ownership.has = info.owned
    ownership.purchased_slots = info.purchased_slots or 0
    
    if info.owned then
        ownership.id = info.id or 1 -- Use proper ID for routing bucket
        -- Create entrance blip for owned warehouse
        if not DoesBlipExist(entranceBlip) then
            entranceBlip = createBlip(Config.Entrance.coords, Config.Blips.Entrance)
        end
    else
        -- For non-owners, check if they have shared warehouse access
        if info.shared_warehouses and #info.shared_warehouses > 0 then
            -- Player has shared warehouse access, keep the entrance blip
            if not DoesBlipExist(entranceBlip) then
                entranceBlip = createBlip(Config.Entrance.coords, Config.Blips.Entrance)
            end
            -- Don't reset ownership.id here as it might be set for shared access
        else
            -- Player has no warehouse access at all
            ownership.id = nil
            ownership.purchased_slots = 0
            -- Remove entrance blip if no access
            if DoesBlipExist(entranceBlip) then
                RemoveBlip(entranceBlip)
                entranceBlip = nil
            end
        end
    end
    
    -- Update UI
    SendNUIMessage({
        action = 'updateWarehouseInfo',
        data = info
    })
end)

RegisterNetEvent('sergeis-warehouse:client:refreshOwnership', function()
    refreshOwnership()
end)

RegisterNetEvent('sergeis-warehouse:client:onWarehouseSold', function()
    ownership.has = false
    ownership.id = nil
    
    -- Remove entrance blip
    if DoesBlipExist(entranceBlip) then
        RemoveBlip(entranceBlip)
        entranceBlip = nil
    end
    
    -- If player is inside warehouse, exit and reset bucket
    if insideWarehouse then
        -- Force exit without triggering server event (since warehouse is sold)
        cleanupInterior()
        
        -- Reset routing bucket locally
        if currentBucket then
            currentBucket = nil
        end
        
        -- Teleport to entrance
        local playerPed = PlayerPedId()
        local exitCoords = Config.Entrance.coords
        teleportWithCollision(playerPed, exitCoords, Config.Entrance.heading)
        
        insideWarehouse = false
        currentWarehouseId = nil
        
        -- Notify server to reset bucket
        TriggerServerEvent('sergeis-warehouse:server:setBucket', 0)
    end
    
    -- Refresh shared warehouses info in case player has access to other warehouses
    TriggerServerEvent('sergeis-warehouse:server:getSharedWarehouses')
end)

RegisterNetEvent('sergeis-warehouse:client:refreshStorage', function()
    if insideWarehouse then
        TriggerServerEvent('sergeis-warehouse:server:getStorageContents')
    end
end)

-- Event to refresh storage grid specifically
RegisterNetEvent('sergeis-warehouse:client:refreshStorageGrid', function()
    -- Refresh the storage grid in the UI
    SendNUIMessage({
        action = 'refreshStorage'
    })
end)

-- Event to refresh crates when slots are purchased
RegisterNetEvent('sergeis-warehouse:client:refreshCrates', function()
    if insideWarehouse and currentAnchor then
        spawnCrates()
    end
end)

-- Event when server-side recovery is complete
RegisterNetEvent('sergeis-warehouse:client:recoveryComplete', function()
    print('[WAREHOUSE] Server-side recovery completed')
    -- Additional cleanup if needed
end)

-- Event when server confirms warehouse exit is complete
RegisterNetEvent('sergeis-warehouse:client:warehouseExitComplete', function()
    print('[WAREHOUSE] Server confirmed warehouse exit completed')
    -- Additional cleanup if needed
end)

-- Recovery function to handle server restarts
local function recoveryFromRestart()
    -- Check if player was in a warehouse when resource restarted
    -- Also check if player is in a warehouse-like area (underground/interior)
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local entranceCoords = Config.Entrance.coords
    
    -- Check if player is underground or in warehouse area
    local shouldRecover = insideWarehouse or currentBucket or 
                         (playerCoords.z < -10.0) or -- Underground
                         (#(playerCoords - entranceCoords) < 200.0 and playerCoords.z < 0.0) -- Near entrance but underground
    
    if shouldRecover then
        print('[WAREHOUSE] Resource restart detected while in warehouse or warehouse area, resetting state...')
        
        -- Reset local state
        insideWarehouse = false
        currentWarehouseId = nil
        currentBucket = nil
        currentAnchor = nil
        currentAnchorHeading = 0.0
        currentLoadedIPLs = nil
        
        -- Also reset shared warehouse state if applicable
        if not ownership.has and ownership.id then
            ownership.id = nil
            ownership.purchased_slots = 0
        end
        
        -- Clean up any remaining props
        cleanupInterior()
        
        -- Request server-side recovery and bucket reset
        TriggerServerEvent('sergeis-warehouse:server:requestRecovery')
        
        -- Always teleport to entrance on resource restart
        teleportWithCollision(playerPed, entranceCoords, Config.Entrance.heading)
        
        QBCore.Functions.Notify('Warehouse session reset due to resource restart', 'info')
    end
    
    -- Always refresh ownership info and shared warehouses
    refreshOwnership()
    
    -- Also refresh shared warehouses info for players who might have access
    TriggerServerEvent('sergeis-warehouse:server:getSharedWarehouses')
end

-- Function to spawn entrance door prop
local function spawnEntranceDoor()
    if not Config.EntranceDoor.enabled then 
        return 
    end
    
    -- List of simple props to try
    local fallbackModels = {
        'v_ilev_ph_door01',
        'v_ilev_ph_door002',
        'v_ilev_ph_door003',
        'v_ilev_fh_frontdoor',
        'prop_door_01',
        'prop_door_02'
    }
    
    local doorCoords = Config.Entrance.coords + Config.EntranceDoor.offset
    local doorHeading = Config.Entrance.heading + Config.EntranceDoor.headingOffset
    
    -- Try the configured model first
    local hash = requestModel(Config.EntranceDoor.model)
    if hash then
        entranceDoor = CreateObject(hash, doorCoords.x, doorCoords.y, doorCoords.z, false, false, false)
        if DoesEntityExist(entranceDoor) then
            SetEntityHeading(entranceDoor, doorHeading)
            FreezeEntityPosition(entranceDoor, true)
            SetEntityAsMissionEntity(entranceDoor, true, true)
            return
        end
    end
    
    -- Try fallback models
    for i, modelName in ipairs(fallbackModels) do
        if modelName ~= Config.EntranceDoor.model then
            local fallbackHash = requestModel(modelName)
            if fallbackHash then
                entranceDoor = CreateObject(fallbackHash, doorCoords.x, doorCoords.y, doorCoords.z, false, false, false)
                if DoesEntityExist(entranceDoor) then
                    SetEntityHeading(entranceDoor, doorHeading)
                    FreezeEntityPosition(entranceDoor, true)
                    SetEntityAsMissionEntity(entranceDoor, true, true)
                    return
                end
            end
        end
    end
    
end

-- Centralized function to open warehouse UI
local function openWarehouseUI()
    -- Check if UI is already open
    if IsNuiFocused() then
        SetNuiFocus(false, false)
        Wait(100) -- Small delay to ensure proper state
    end
    
    -- Check if player is at warehouse entrance
    local playerCoords = GetEntityCoords(PlayerPedId())
    local entranceDist = #(playerCoords - Config.Entrance.coords)
    local isAtEntrance = entranceDist < Config.Entrance.markerRange
    
    -- Ensure NUI focus is properly set
    SetNuiFocus(true, true)
    
    -- Check if player has any warehouse access (owned or shared)
    local hasAnyWarehouseAccess = ownership.has or (ownership.id and not ownership.has)
    
    if isAtEntrance and hasAnyWarehouseAccess then
        -- Player is at entrance and has warehouse access - show selection modal
        SendNUIMessage({
            action = 'showWarehouseSelection'
        })
    else
        -- Player is at sales ped or doesn't have warehouse access - show main UI
        SendNUIMessage({
            action = 'showUI',
            show = true
        })
    end
end

-- Initialize
CreateThread(function()
    -- Create sales ped
    salesPedId = createPed(Config.SalesPed.model, Config.SalesPed.coords, Config.SalesPed.scenario)
    
    -- Create blips
    createBlip(Config.SalesPed.coords, Config.Blips.SalesPed)
    
    -- Spawn entrance door prop
    spawnEntranceDoor()
    
    -- Add target integration for sales ped
    if salesPedId and Config.TargetSystem == 'qb-target' and exports['qb-target'] then
        exports['qb-target']:AddTargetEntity(salesPedId, {
            options = {
                {
                    label = Config.SalesPed.targetLabel or 'Warehouse Services',
                    icon = 'fas fa-warehouse',
                    action = function()
                        openWarehouseUI()
                    end
                }
            },
            distance = 2.0
        })
    elseif salesPedId and Config.TargetSystem == 'ox_target' and exports.ox_target then
        exports.ox_target:addLocalEntity(salesPedId, {
            {
                name = 'sergeis_warehouse_sales',
                label = Config.SalesPed.targetLabel or 'Warehouse Services',
                icon = 'fa-solid fa-warehouse',
                onSelect = function()
                    openWarehouseUI()
                end
            }
        })
    end

    -- Refresh ownership on resource start - increased delay to ensure QBCore is fully loaded
    Wait(5000)
    refreshOwnership()
    
    -- Recovery system for server restarts
    recoveryFromRestart()
    
    -- Additional recovery check after a longer delay
    CreateThread(function()
        Wait(10000) -- 10 seconds
        recoveryFromRestart()
    end)
end)

-- Main thread
CreateThread(function()
    while true do
        local sleep = 1000
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)

        -- Sales ped interaction (fallback if no target system)
        if not (Config.TargetSystem == 'qb-target' or Config.TargetSystem == 'ox_target') then
            local salesDist = #(playerCoords - vector3(Config.SalesPed.coords.x, Config.SalesPed.coords.y, Config.SalesPed.coords.z))
            if salesDist < 2.0 then
                sleep = 0
                draw3DText(vector3(Config.SalesPed.coords.x, Config.SalesPed.coords.y, Config.SalesPed.coords.z + 1.0), '~g~E~s~ - Warehouse Services')
                if IsControlJustPressed(0, 38) then -- E key
                    openWarehouseUI()
                end
            end
        end

        -- Only show entrance marker when NOT inside any warehouse
        if not insideWarehouse then
            -- Check if player has any warehouse access (owned or shared)
            local hasAnyWarehouseAccess = ownership.has or (ownership.id and not ownership.has)
            
            if not hasAnyWarehouseAccess then
                -- Show entrance marker for players with no warehouse access
                local entranceDist = #(playerCoords - Config.Entrance.coords)
                if entranceDist < Config.DrawDistance then
                    sleep = 0
                    DrawMarker(1, Config.Entrance.coords.x, Config.Entrance.coords.y, Config.Entrance.coords.z - 1.0, 
                        0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 
                        1.0, 1.0, 1.0, 255, 255, 255, 100, 
                        false, true, 2, false, nil, nil, false)
                    
                    if entranceDist < Config.Entrance.markerRange then
                        draw3DText(Config.Entrance.coords, 'Talk to the ~y~Sales Ped~s~ to buy a warehouse')
                    end
                end
            else
                -- Show entrance marker for players with warehouse access (owned or shared)
                local entranceDist = #(playerCoords - Config.Entrance.coords)
                if entranceDist < Config.DrawDistance then
                    sleep = 0
                    DrawMarker(1, Config.Entrance.coords.x, Config.Entrance.coords.y, Config.Entrance.coords.z - 1.0, 
                        0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 
                        1.0, 1.0, 1.0, 40, 200, 60, 150, 
                        false, true, 2, false, nil, nil, false)
                    
                    if entranceDist < Config.Entrance.markerRange then
                        if ownership.has then
                            draw3DText(Config.Entrance.coords, 'Press ~y~E~w~ to enter warehouse')
                        else
                            draw3DText(Config.Entrance.coords, 'Press ~y~E~w~ to access shared warehouse')
                        end
                        
                        if IsControlJustPressed(0, 38) then -- E key
                            -- Show warehouse selection modal for both owned and shared warehouses
                            openWarehouseUI()
                        end
                    end
                end
            end
        end

        if insideWarehouse and currentAnchor then
            -- Show exit marker
            local exitCoords = vector3(
                currentAnchor.x + Config.Exit.offset.x,
                currentAnchor.y + Config.Exit.offset.y,
                currentAnchor.z + Config.Exit.offset.z
            )
            
            local exitDist = #(playerCoords - exitCoords)
            if exitDist < Config.DrawDistance then
                sleep = 0
                DrawMarker(1, exitCoords.x, exitCoords.y, exitCoords.z - 1.0, 
                    0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 
                    1.0, 1.0, 1.0, 255, 255, 255, 100, 
                    false, true, 2, false, nil, nil, false)
                
                if exitDist < Config.Exit.markerRange then
                    draw3DText(exitCoords, 'Press ~y~E~w~ to exit warehouse')
                    if IsControlJustPressed(0, 38) then -- E key
                        exitWarehouse()
                    end
                end
            end
        end

        Wait(sleep)
    end
end)



-- Cleanup on resource stop
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        cleanupInterior()
        if salesPedId and DoesEntityExist(salesPedId) then
            DeleteEntity(salesPedId)
        end
        if entranceDoor and DoesEntityExist(entranceDoor) then
            DeleteEntity(entranceDoor)
        end
    end
end)

-- Recovery on resource start
AddEventHandler('onClientResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        print('[WAREHOUSE] Resource started, initiating recovery...')
        -- Wait a bit for everything to load, then run recovery
        Wait(2000)
        recoveryFromRestart()
        
        -- Backup recovery after a longer delay in case first one fails
        CreateThread(function()
            Wait(5000)
            recoveryFromRestart()
        end)
    end
end)

-- NUI Callbacks
RegisterNUICallback('buyWarehouse', function(data, cb)
    TriggerServerEvent('sergeis-warehouse:server:buyWarehouse')
    cb('ok')
end)

RegisterNUICallback('sellWarehouse', function(data, cb)
    TriggerServerEvent('sergeis-warehouse:server:sellWarehouse')
    cb('ok')
end)

RegisterNUICallback('buyStorageSlots', function(data, cb)
    local slotCount = tonumber(data.slotCount) or 1
    if slotCount and slotCount > 0 and slotCount <= Config.Warehouse.maxSlots then
        TriggerServerEvent('sergeis-warehouse:server:buyStorageSlots', slotCount)
        cb('ok')
    else
        QBCore.Functions.Notify('Invalid slot count', 'error')
        cb('error')
    end
end)

RegisterNUICallback('buySpecificSlot', function(data, cb)
    local slotNumber = tonumber(data.slotNumber) or 1
    if slotNumber and slotNumber > 0 and slotNumber <= Config.Warehouse.maxSlots then
        TriggerServerEvent('sergeis-warehouse:server:buySpecificSlot', slotNumber)
        cb('ok')
    else
        QBCore.Functions.Notify('Invalid slot number', 'error')
        cb('error')
    end
end)

RegisterNUICallback('closeUI', function(data, cb)
    
    -- Force remove NUI focus completely
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    
    cb('ok')
end)







-- ========================================
-- WAREHOUSE SHARING SYSTEM FUNCTIONS
-- ========================================

-- Share warehouse with player
RegisterNUICallback('shareWarehouse', function(data, cb)
    local targetCitizenId = data.targetCitizenId
    local permissionLevel = data.permissionLevel or 'read'
    local expiresAt = data.expiresAt or nil
    
    if not targetCitizenId then
        QBCore.Functions.Notify('Please provide a valid player ID', 'error')
        cb('error')
        return
    end
    
    TriggerServerEvent('sergeis-warehouse:server:shareWarehouse', targetCitizenId, permissionLevel, expiresAt)
    cb('ok')
end)

-- Revoke warehouse access
RegisterNUICallback('revokeAccess', function(data, cb)
    local targetCitizenId = data.targetCitizenId
    
    if not targetCitizenId then
        QBCore.Functions.Notify('Please provide a valid player ID', 'error')
        cb('error')
        return
    end
    
    TriggerServerEvent('sergeis-warehouse:server:revokeAccess', targetCitizenId)
    cb('ok')
end)

-- Update sharing permissions
RegisterNUICallback('updateSharingPermissions', function(data, cb)
    local targetCitizenId = data.targetCitizenId
    local newPermissionLevel = data.permissionLevel
    
    if not targetCitizenId or not newPermissionLevel then
        QBCore.Functions.Notify('Please provide valid parameters', 'error')
        cb('error')
        return
    end
    
    TriggerServerEvent('sergeis-warehouse:server:updateSharingPermissions', targetCitizenId, newPermissionLevel)
    cb('ok')
end)

-- Get shared warehouses
RegisterNUICallback('getSharedWarehouses', function(data, cb)
    TriggerServerEvent('sergeis-warehouse:server:getSharedWarehouses')
    cb('ok')
end)

-- Access shared warehouse
RegisterNUICallback('accessSharedWarehouse', function(data, cb)
    local warehouseId = data.warehouseId
    
    if not warehouseId then
        QBCore.Functions.Notify('Invalid warehouse ID', 'error')
        cb('error')
        return
    end
    
    -- Enter the shared warehouse
    enterSharedWarehouse(warehouseId)
    cb('ok')
end)

-- Load nearby players
RegisterNUICallback('loadNearbyPlayers', function(data, cb)
    print("^2[WAREHOUSE] NUI callback loadNearbyPlayers triggered^7")
    
    -- Request server to get nearby players
    TriggerServerEvent('sergeis-warehouse:server:loadNearbyPlayers')
    
    cb('ok')
end)

-- Enter owned warehouse
RegisterNUICallback('enterOwnedWarehouse', function(data, cb)
    print("^2[WAREHOUSE] NUI callback enterOwnedWarehouse triggered^7")
    
    -- Enter the owned warehouse
    enterWarehouse()
    
    cb('ok')
end)

-- Client events for sharing system
RegisterNetEvent('sergeis-warehouse:client:updateWarehouseInfo', function(info)
    if info.owned then
        ownership.has = true
        ownership.id = info.id
        ownership.purchased_slots = info.purchased_slots
        
        -- Update UI with warehouse info
        SendNUIMessage({
            action = 'updateWarehouseInfo',
            data = info
        })
    else
        ownership.has = false
        ownership.id = nil
        ownership.purchased_slots = 0
        
        -- Update UI with shared warehouses info
        SendNUIMessage({
            action = 'updateSharedWarehouses',
            data = info.shared_warehouses
        })
    end
end)

RegisterNetEvent('sergeis-warehouse:client:updateSharedWarehouses', function(sharedWarehouses)
    SendNUIMessage({
        action = 'updateSharedWarehouses',
        data = sharedWarehouses
    })
end)

RegisterNetEvent('sergeis-warehouse:client:refreshSharing', function()
    -- Refresh sharing information
    TriggerServerEvent('sergeis-warehouse:server:getWarehouseInfo')
end)

-- Receive nearby players search results
RegisterNetEvent('sergeis-warehouse:client:nearbyPlayersResults', function(players)
    print("^2[WAREHOUSE] Client received nearby players: " .. #players .. " players^7")
    for i, player in ipairs(players) do
        print("^3[WAREHOUSE] Player " .. i .. ": " .. player.firstname .. " " .. player.lastname .. " (ID: " .. player.citizenid .. ", Distance: " .. player.distance .. "m)^7")
    end
    
    print("^2[WAREHOUSE] Sending NUI message with action: updatePlayerResults^7")
    SendNUIMessage({
        action = 'updatePlayerResults',
        players = players
    })
    print("^2[WAREHOUSE] NUI message sent^7")
end)

-- Teleport to warehouse interior (for shared warehouses)
RegisterNetEvent('sergeis-warehouse:client:teleportToInterior', function(interiorCoords)
    print("^2[WAREHOUSE] Teleporting to warehouse interior at " .. tostring(interiorCoords) .. "^7")
    
    local playerPed = PlayerPedId()
    
    -- Set up warehouse configuration (same as enterWarehouse function)
    local warehouseCfg = Config.Warehouse
    if not warehouseCfg or not warehouseCfg.interiorAnchor then
        QBCore.Functions.Notify('Warehouse configuration error: missing interior anchor configuration', 'error')
        return
    end
    
    -- Set all necessary configuration values
    currentAnchor = warehouseCfg.interiorAnchor
    currentAnchorHeading = currentAnchor.w or 0.0
    currentLoadedIPLs = warehouseCfg.ipls
    
    -- Safety check: ensure currentAnchor is valid
    if not currentAnchor then
        QBCore.Functions.Notify('Warehouse configuration error: invalid interior anchor', 'error')
        return
    end
    
    -- Load IPLs for the warehouse interior
    loadIPLs(currentLoadedIPLs)
    
    -- Set player coordinates to warehouse interior
    SetEntityCoords(playerPed, interiorCoords.x, interiorCoords.y, interiorCoords.z)
    SetEntityHeading(playerPed, interiorCoords.w)
    
    -- Mark as inside warehouse
    insideWarehouse = true
    
    print("^2[WAREHOUSE] Successfully teleported to warehouse interior^7")
    print("^2[WAREHOUSE] insideWarehouse: " .. tostring(insideWarehouse) .. "^7")
    print("^2[WAREHOUSE] currentAnchor: " .. tostring(currentAnchor) .. "^7")
    print("^2[WAREHOUSE] currentAnchorHeading: " .. tostring(currentAnchorHeading) .. "^7")
    print("^2[WAREHOUSE] ownership.id: " .. tostring(ownership.id) .. "^7")
    
    -- Small delay to ensure all state is properly set
    Wait(100)
    
    -- Double-check that we're still inside the warehouse
    if insideWarehouse then
        print("^2[WAREHOUSE] State verification successful - player remains inside warehouse^7")
        
        -- Verify all configuration values are set
        if not currentAnchor then
            print("^1[WAREHOUSE] ERROR: currentAnchor is nil after setup^7")
            currentAnchor = warehouseCfg.interiorAnchor
        end
        
        if not currentAnchorHeading then
            print("^1[WAREHOUSE] ERROR: currentAnchorHeading is nil after setup^7")
            currentAnchorHeading = currentAnchor.w or 0.0
        end
        
        -- Spawn warehouse interior and crates for shared warehouses
        if not ownership.has then -- This is a shared warehouse
            print("^2[WAREHOUSE] Spawning shared warehouse interior and crates^7")
            spawnCrates()
        end
    else
        print("^1[WAREHOUSE] WARNING: insideWarehouse state was reset unexpectedly!^7")
        -- Restore the state
        insideWarehouse = true
    end
end)

-- Receive shared warehouse info for crate spawning
RegisterNetEvent('sergeis-warehouse:client:receiveSharedWarehouseInfo', function(warehouseInfo)
    print("^2[WAREHOUSE] Received shared warehouse info: " .. warehouseInfo.purchased_slots .. " slots^7")
    
    -- Store the warehouse info temporarily for crate spawning
    local tempWarehouseInfo = {
        purchased_slots = warehouseInfo.purchased_slots,
        max_slots = warehouseInfo.max_slots
    }
    
    -- Spawn crates with the received slot count
    spawnCratesWithSlots(tempWarehouseInfo.purchased_slots)
end)

-- Function to enter shared warehouse
function enterSharedWarehouse(warehouseId)
    print("^2[WAREHOUSE] Entering shared warehouse with ID: " .. warehouseId .. "^7")
    
    -- Set the current warehouse ID for shared access
    ownership.id = warehouseId
    ownership.has = false -- Mark as shared, not owned
    currentWarehouseId = warehouseId -- Track which warehouse we're currently in
    
    print("^2[WAREHOUSE] Shared warehouse state set - ownership.id: " .. tostring(ownership.id) .. ", ownership.has: " .. tostring(ownership.has) .. ", currentWarehouseId: " .. tostring(currentWarehouseId) .. "^7")
    
    -- Mark as entering warehouse to prevent immediate exit
    insideWarehouse = true
    
    -- Use warehouse-based bucket for consistency with owned warehouses
    currentBucket = warehouseId
    print("^2[WAREHOUSE] Set client bucket ID: " .. warehouseId .. "^7")
    
    -- Trigger server to validate access and create bucket
    -- The server will handle teleportation to the correct warehouse interior
    TriggerServerEvent('sergeis-warehouse:server:enterSharedWarehouse', warehouseId)
    
    QBCore.Functions.Notify('Entering shared warehouse...', 'info')
    
    -- Wait for teleportation to complete, then spawn warehouse interior
    CreateThread(function()
        Wait(500) -- Wait for teleportation
        
        -- Spawn warehouse interior and crates
        if insideWarehouse and currentAnchor then
            print("^2[WAREHOUSE] Spawning warehouse interior for shared warehouse^7")
            spawnCrates()
        else
            print("^1[WAREHOUSE] ERROR: Cannot spawn crates - insideWarehouse: " .. tostring(insideWarehouse) .. ", currentAnchor: " .. tostring(currentAnchor) .. "^7")
        end
    end)
end

-- Function to update warehouse sharing permissions
function updateWarehouseSharing(targetCitizenId, newPermission, newExpiresAt)
    print("^2[WAREHOUSE] Updating sharing permissions for " .. targetCitizenId .. " to " .. newPermission .. "^7")
    
    TriggerServerEvent('sergeis-warehouse:server:updateWarehouseSharing', targetCitizenId, newPermission, newExpiresAt)
    
    -- Wait a moment for the server to process, then refresh the UI
    CreateThread(function()
        Wait(500) -- Wait for server processing
        
        -- Refresh warehouse info to get updated shared users list
        TriggerServerEvent('sergeis-warehouse:server:getWarehouseInfo')
        
        print("^2[WAREHOUSE] Requested warehouse info refresh after updating permissions^7")
    end)
end

-- Function to revoke warehouse sharing access
function revokeWarehouseSharing(targetCitizenId)
    print("^2[WAREHOUSE] Revoking sharing access for " .. targetCitizenId .. "^7")
    
    TriggerServerEvent('sergeis-warehouse:server:revokeWarehouseSharing', targetCitizenId)
    
    -- Wait a moment for the server to process, then refresh the UI
    CreateThread(function()
        Wait(500) -- Wait for server processing
        
        -- Refresh warehouse info to get updated shared users list
        TriggerServerEvent('sergeis-warehouse:server:getWarehouseInfo')
        
        print("^2[WAREHOUSE] Requested warehouse info refresh after revoking access^7")
    end)
end

-- Function to reset shared warehouse state
function resetSharedWarehouseState()
    print('[WAREHOUSE] Resetting shared warehouse state')
    
    -- Only reset if this was a shared warehouse (not owned)
    if not ownership.has and ownership.id then
        ownership.id = nil
        ownership.purchased_slots = 0
        currentWarehouseId = nil
        
        print('[WAREHOUSE] Shared warehouse state reset - ownership.id:', ownership.id, 'currentWarehouseId:', currentWarehouseId)
        
        -- Refresh warehouse info to get updated shared warehouses list
        TriggerServerEvent('sergeis-warehouse:server:getWarehouseInfo')
    end
end

-- NUI Callbacks for sharing management
RegisterNUICallback('updateWarehouseSharing', function(data, cb)
    if data.targetCitizenId and data.newPermission then
        updateWarehouseSharing(data.targetCitizenId, data.newPermission, data.newExpiresAt)
        cb('ok')
    else
        cb('error')
    end
end)

RegisterNUICallback('revokeWarehouseSharing', function(data, cb)
    if data.targetCitizenId then
        revokeWarehouseSharing(data.targetCitizenId)
        cb('ok')
    else
        cb('error')
    end
end)



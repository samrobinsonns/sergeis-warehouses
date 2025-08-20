local QBCore = exports['qb-core']:GetCoreObject()

-- Variables
local ownership = { has = false, id = nil, purchased_slots = 0 }
local currentAnchor = nil
local currentAnchorHeading = 0.0
local currentLoadedIPLs = nil
local currentBucket = nil
local insideWarehouse = false
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
    
    if not ownership.has then
        QBCore.Functions.Notify('You do not own this warehouse', 'error')
        return
    end
    
    -- Check if crate is within purchased slots
    if crateIndex > ownership.purchased_slots then
        QBCore.Functions.Notify('This storage crate is not available', 'error')
        return
    end
    
    -- Trigger server event to open storage
    TriggerServerEvent('sergeis-warehouse:server:openCrateStorage', crateIndex)
    
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
    if not Config.Warehouse.crates then 
        return 
    end
    
    -- Clear existing crates first
    for _, crate in ipairs(shelvedProps) do
        if DoesEntityExist(crate) then
            DeleteEntity(crate)
        end
    end
    shelvedProps = {}
    
    -- Only spawn crates for purchased slots
    local slotsToSpawn = ownership.purchased_slots or 0
    
    for i = 1, slotsToSpawn do
        if i <= #Config.Warehouse.crates then
            local crateCfg = Config.Warehouse.crates[i]
            
            local hash = requestModel(crateCfg.model)
            if hash then
                local crate = CreateObject(hash, 
                    currentAnchor.x + crateCfg.offset.x, 
                    currentAnchor.y + crateCfg.offset.y, 
                    currentAnchor.z + crateCfg.offset.z, 
                    false, false, false)
                
                if DoesEntityExist(crate) then
                    SetEntityHeading(crate, currentAnchorHeading + crateCfg.heading)
                    FreezeEntityPosition(crate, true)
                    SetEntityAsMissionEntity(crate, true, true)
                    table.insert(shelvedProps, crate)
                    
                    -- Add target integration for the crate
                    addCrateTarget(crate, i)
                end
            end
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

local function enterWarehouse()
    if not ownership.has then
        QBCore.Functions.Notify('You do not own a warehouse', 'error')
        return
    end
    
    local warehouseCfg = Config.Warehouse
    currentAnchor = warehouseCfg.interiorAnchor
    currentAnchorHeading = currentAnchor.w
    currentLoadedIPLs = warehouseCfg.ipls
    
    -- Load IPLs
    loadIPLs(currentLoadedIPLs)
    
    -- Create routing bucket
    currentBucket = ownership.id
    TriggerServerEvent('sergeis-warehouse:server:setBucket', currentBucket)
    
    -- Teleport to interior
    local playerPed = PlayerPedId()
    teleportWithCollision(playerPed, vector3(currentAnchor.x, currentAnchor.y, currentAnchor.z), currentAnchorHeading)
    
    -- Wait for teleport to complete
    Wait(1000)
    
    -- Spawn crates based on current slot count
    spawnCrates()
    
    insideWarehouse = true
end

local function exitWarehouse()
    if not insideWarehouse then return end
    
    -- Clean up interior
    cleanupInterior()
    
    -- Reset routing bucket
    if currentBucket then
        TriggerServerEvent('sergeis-warehouse:server:setBucket', 0)
        currentBucket = nil
    end
    
    -- Teleport to entrance
    local playerPed = PlayerPedId()
    local exitCoords = Config.Entrance.coords
    teleportWithCollision(playerPed, exitCoords, Config.Entrance.heading)
    
    insideWarehouse = false
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
        ownership.id = nil
        ownership.purchased_slots = 0
        -- Remove entrance blip if no longer owned
        if DoesBlipExist(entranceBlip) then
            RemoveBlip(entranceBlip)
            entranceBlip = nil
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
    if insideWarehouse then
        exitWarehouse()
    end
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

-- Recovery function to handle server restarts
local function recoveryFromRestart()
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    
    -- Check if player is near warehouse interior coordinates
    local warehouseCoords = Config.Warehouse.interiorAnchor
    local distanceToWarehouse = #(playerCoords - vector3(warehouseCoords.x, warehouseCoords.y, warehouseCoords.z))
    
    if distanceToWarehouse < 100.0 then
        -- Teleport to entrance
        teleportWithCollision(playerPed, Config.Entrance.coords, Config.Entrance.heading)
        QBCore.Functions.Notify('You were returned to the warehouse entrance after a restart', 'primary')
    end
    
    -- Reset warehouse state
    insideWarehouse = false
    currentBucket = nil
    currentAnchor = nil
    currentAnchorHeading = 0.0
    
    -- Clean up any existing props
    cleanupInterior()
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
    
    -- Ensure NUI focus is properly set
    SetNuiFocus(true, true)
    
    -- Send message to show UI
    SendNUIMessage({
        action = 'showUI',
        show = true
    })
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

    -- Refresh ownership on resource start
    Wait(1000)
    refreshOwnership()
    
    -- Recovery system for server restarts
    recoveryFromRestart()
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

        if not ownership.has then
            -- Show entrance marker
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
            -- Show entrance marker for owned warehouse
            local entranceDist = #(playerCoords - Config.Entrance.coords)
            if entranceDist < Config.DrawDistance then
                sleep = 0
                DrawMarker(1, Config.Entrance.coords.x, Config.Entrance.coords.y, Config.Entrance.coords.z - 1.0, 
                    0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 
                    1.0, 1.0, 1.0, 40, 200, 60, 150, 
                    false, true, 2, false, nil, nil, false)
                
                if entranceDist < Config.Entrance.markerRange then
                    draw3DText(Config.Entrance.coords, 'Press ~y~E~w~ to enter warehouse')
                    if IsControlJustPressed(0, 38) then -- E key
                        enterWarehouse()
                    end
                end
            end
        end

        if insideWarehouse then
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
        -- Wait a bit for everything to load, then run recovery
        Wait(2000)
        recoveryFromRestart()
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

-- Command to open UI
RegisterCommand('warehouse', function()
    if ownership.has then
        openWarehouseUI()
    else
        QBCore.Functions.Notify('You do not own a warehouse', 'error')
    end
end)

-- Key binding
RegisterKeyMapping('warehouse', 'Open Warehouse Menu', 'keyboard', 'F6')



Config = {}

-- General
Config.Debug = false
Config.Locale = 'en'
Config.AllowMultipleWarehouses = false -- one per citizen by default
Config.TargetSystem = 'ox_target' -- 'ox_target' or 'qb-target'
Config.InventorySystem = 'ox_inventory' -- 'ox_inventory' or 'qb-inventory'

-- Money source for purchase
Config.PurchaseAccount = 'bank'
Config.SellAccount = 'bank' -- Account type for receiving sell money (can be 'bank', 'cash', or 'crypto')

-- Single warehouse configuration
Config.Warehouse = {
    price = 150000, -- Base warehouse price
    sellPrice = 75000, -- Warehouse sell price (50% of purchase price)
    slotPrice = 5000, -- Price per additional storage slot
    maxSlots = 6, -- Maximum storage slots a player can purchase (matches 6 crates)
    
    -- Interior settings - Correct Executive Small Warehouse coordinates
    interiorAnchor = vector4(1094.988, -3101.776, -39.00363, 0.0),
    ipls = {
        'ex_exec_warehouse_placement_interior_1_int_warehouse_s_dlc_milo',
    },
    exitOffset = vector3(-7.33, 2.48, 0.00),
    
    -- Storage configuration - using closed crates positioned along warehouse wall
    crates = {
        -- Wall-mounted crates with exact positioning (dropped down to floor level)
        { model = 'ex_prop_crate_closed_bc', offset = vec3(-6.34, 5.39, -1.0), heading = 174.60 },
        { model = 'ex_prop_crate_closed_bc', offset = vec3(-3.85, 5.26, -1.0), heading = 183.00 },
        { model = 'ex_prop_crate_closed_bc', offset = vec3(0.07, 5.32, -1.0), heading = 180.59 },
        { model = 'ex_prop_crate_closed_bc', offset = vec3(2.57, 5.12, -1.0), heading = 176.24 },
        { model = 'ex_prop_crate_closed_bc', offset = vec3(6.29, 5.22, -1.0), heading = 168.63 },
        { model = 'ex_prop_crate_closed_bc', offset = vec3(8.82, 5.04, -1.0), heading = 177.88 },
    },
    
    -- Storage slot positions (relative to crates) - 4 slots per crate
    crateSlots = {
        -- Front slots (closest to player)
        vec3(0.0, 0.0, 0.5), vec3(0.0, 0.0, 1.0),
        vec3(0.5, 0.0, 0.5), vec3(0.5, 0.0, 1.0),
        -- Middle slots
        vec3(0.0, 0.0, 1.5), vec3(0.0, 0.0, 2.0),
        vec3(0.5, 0.0, 1.5), vec3(0.5, 0.0, 2.0),
        -- Back slots
        vec3(0.0, 0.0, 2.5), vec3(0.0, 0.0, 3.0),
        vec3(0.5, 0.0, 2.5), vec3(0.5, 0.0, 3.0),
        -- Side slots
        vec3(0.0, 0.0, 3.5), vec3(0.0, 0.0, 4.0),
        vec3(0.5, 0.0, 3.5), vec3(0.5, 0.0, 4.0),
    }
}

-- Sales Ped
Config.SalesPed = {
    model = 's_m_m_dockwork_01',
    coords = vector4(-57.34, -2659.82, 6.0, 351.66),
    scenario = 'WORLD_HUMAN_CLIPBOARD',
    targetLabel = 'Warehouse Services'
}

-- Public entrance marker
Config.Entrance = {
    coords = vector3(-59.87, -2660.43, 6.0),
    heading = 89.0,
    markerDrawDistance = 15.0,
    markerRange = 1.5
}

-- Entrance door prop for visual clarity
Config.EntranceDoor = {
    enabled = true,
    model = 'v_ilev_ph_door01', -- Office door that should work
    offset = vector3(0.0, 0.0, 0.5), -- Keep the raised offset that worked
    headingOffset = 0.0 -- Relative to entrance heading
}

-- Exit marker inside interior
Config.Exit = {
    offset = vec3(-7.41, 2.38, 0.00),
    markerRange = 1.8
}

-- Blips
Config.Blips = {
    SalesPed = { sprite = 478, color = 5, scale = 0.8, text = 'Warehouse Sales', shortRange = false },
    Entrance = { sprite = 50, color = 3, scale = 0.65, text = 'Your Warehouse', shortRange = true }
}

-- Stash settings for storage slots
Config.Storage = {
    maxWeight = 100000,
    maxSlots = 30,
    -- ox_inventory specific settings
    ox_inventory = {
        maxWeight = 100000,
        maxSlots = 30
    },
    -- qb-inventory specific settings
    qb_inventory = {
        maxWeight = 100000,
        maxSlots = 30
    }
}

-- Distances
Config.DrawDistance = 30.0
Config.InteractDistance = 2.0



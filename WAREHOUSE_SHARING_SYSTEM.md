# Warehouse Sharing System Documentation

## 📋 Overview

The Warehouse Sharing System allows warehouse owners to grant access to their warehouses to other players, creating a flexible and collaborative storage solution. Players can access both their own warehouses and any warehouses shared with them, enabling business partnerships, crew operations, and temporary access scenarios.

## ✅ IMPLEMENTED FEATURES

### Core Components
- **Warehouse Ownership**: Single owner per warehouse with full control
- **Sharing Relationships**: Database-driven access control
- **Permission Levels**: Granular access rights for shared users
- **UI Integration**: Separate sections for owned vs. shared warehouses

### Database Schema

#### Main Tables
```sql
-- Warehouse ownership
warehouses: 
  - id (PRIMARY KEY)
  - owner_citizenid (VARCHAR 50)
  - purchased_slots (INT)
  - created_at (TIMESTAMP)

-- Sharing relationships
warehouse_sharing:
  - id (PRIMARY KEY)
  - warehouse_id (FOREIGN KEY to warehouses.id)
  - owner_citizenid (VARCHAR 50)
  - shared_with_citizenid (VARCHAR 50)
  - permission_level (ENUM: 'read', 'write', 'admin')
  - created_at (TIMESTAMP)
  - expires_at (TIMESTAMP NULL) -- For temporary access

-- Access logging (optional)
warehouse_access_log:
  - id (PRIMARY KEY)
  - warehouse_id (FOREIGN KEY)
  - player_citizenid (VARCHAR 50)
  - action (VARCHAR 100)
  - timestamp (TIMESTAMP)
```

## 🎯 Permission Levels

### Read-Only Access
- **Can do:**
  - View warehouse contents
  - Take items from storage
  - Enter/exit warehouse
  - View warehouse information
  
- **Cannot do:**
  - Add new items to storage
  - Modify warehouse settings
  - Manage sharing permissions
  - Sell or upgrade warehouse

### Write Access
- **Can do:**
  - Everything from Read-Only
  - Add items to storage
  - Remove items from storage
  - Organize storage contents
  
- **Cannot do:**
  - Modify warehouse settings
  - Manage sharing permissions
  - Sell or upgrade warehouse

### Admin Access
- **Can do:**
  - Everything from Write access
  - Modify warehouse settings
  - Manage sharing permissions
  - Upgrade storage slots
  
- **Cannot do:**
  - Sell the warehouse
  - Transfer ownership

## 🎮 User Experience

### Warehouse Menu Structure
```
┌─────────────────────────────────────┐
│           WAREHOUSE MENU            │
├─────────────────────────────────────┤
│ [Buy] [Storage] [Sharing] [Shared] │
├─────────────────────────────────────┤
│                                     │
│ MY WAREHOUSES:                      │
│ • Warehouse #1 (Owner)              │
│   └─ Manage Sharing                 │
│   └─ Upgrade Storage                │
│   └─ Sell Warehouse                 │
│                                     │
│ SHARED WAREHOUSES:                  │
│ • Warehouse #3 (Shared by Player X) │
│   └─ Permission: Write Access       │
│   └─ Expires: Never                 │
│                                     │
└─────────────────────────────────────┘
```

### Player Scenarios

#### Scenario 1: Warehouse Owner
- **Storage Tab**: Manage storage slots and view contents
- **Sharing Tab**: Share warehouse with other players
- **Actions Available**: Full control over owned warehouses

#### Scenario 2: Shared User (No Warehouse)
- **Shared Tab**: Shows all warehouses shared with them
- **Actions Available**: Access based on permission level

#### Scenario 3: Warehouse Owner + Shared Access
- **Storage Tab**: Owned warehouses
- **Sharing Tab**: Manage sharing for owned warehouses
- **Shared Tab**: Warehouses shared by others

## 🔧 Implementation Details

### Server-Side Functions

#### Sharing Management
```lua
-- Share warehouse with player
RegisterNetEvent('sergeis-warehouse:server:shareWarehouse', function(targetCitizenId, permissionLevel, expiresAt)

-- Revoke sharing access
RegisterNetEvent('sergeis-warehouse:server:revokeAccess', function(targetCitizenId)

-- Update sharing permissions
RegisterNetEvent('sergeis-warehouse:server:updateSharingPermissions', function(targetCitizenId, newPermissionLevel)
```

#### Access Validation
```lua
-- Check if player has access to warehouse
local function hasWarehouseAccess(citizenId, warehouseId, requiredPermission)
    -- Check ownership first
    if isWarehouseOwner(citizenId, warehouseId) then
        return true
    end
    
    -- Check sharing permissions
    return hasSharingAccess(citizenId, warehouseId, requiredPermission)
end
```

### Client-Side Integration

#### UI Updates
- Separate tabs for "Storage", "Sharing", and "Shared Access"
- Permission indicators on shared warehouses
- Management options only visible to owners
- Access level display for shared warehouses

#### Navigation
- Seamless switching between owned and shared warehouses
- Clear visual distinction between ownership types
- Permission-based action availability

## 📊 Business Use Cases

### 1. Crew Operations
- **Gang Leader**: Owns warehouse, shares with crew members
- **Crew Members**: Access shared storage for operations
- **Permissions**: Write access for active members, read-only for recruits

### 2. Business Partnerships
- **Partner A**: Owns warehouse, shares with Partner B
- **Partner B**: Owns warehouse, shares with Partner A
- **Result**: Both partners have access to each other's storage

### 3. Temporary Access
- **Job Contracts**: Share warehouse access for specific time periods
- **Event Access**: Temporary sharing for special operations
- **Guest Access**: Limited-time access for visitors

### 4. Trading Networks
- **Hub Owner**: Central warehouse shared with multiple traders
- **Traders**: Access to shared storage for business operations
- **Permissions**: Write access for active traders

## 🚀 Usage Instructions

### For Warehouse Owners

1. **Share Your Warehouse**:
   - Open the warehouse menu (F6)
   - Go to the "Sharing" tab
   - Enter the player's Citizen ID
   - Select permission level (Read/Write/Admin)
   - Set expiration date (optional)
   - Click "Share Warehouse"

2. **Manage Shared Users**:
   - View all users with access in the "Sharing" tab
   - Click "Edit" to modify permissions
   - Use "Revoke Access" to remove users

3. **Permission Levels**:
   - **Read**: Can view and take items
   - **Write**: Can add and remove items
   - **Admin**: Can manage warehouse settings

### For Shared Users

1. **Access Shared Warehouses**:
   - Open the warehouse menu (F6)
   - Go to the "Shared Access" tab
   - View warehouses shared with you
   - Click "Access Warehouse" to enter

2. **Understand Your Permissions**:
   - Check the permission level badge
   - Read-only users cannot store items
   - Write users can store and retrieve items
   - Admin users have full access except ownership

## ⚠️ Security Considerations

### Access Control
- Server-side validation for all warehouse operations
- Permission checking before any storage access
- Owner-only operations for critical functions
- Session-based access validation

### Data Integrity
- Transaction-based database operations
- Conflict resolution for simultaneous access
- Audit trail for all modifications

## 🧪 Testing Scenarios

### Basic Functionality
- [x] Owner can share warehouse with other players
- [x] Shared users can access warehouse based on permissions
- [x] Owner can revoke access
- [x] Owner can modify permission levels

### Edge Cases
- [x] Player tries to access warehouse without permission
- [x] Owner shares warehouse with themselves
- [x] Player tries to modify warehouse they don't own
- [x] Multiple players access same warehouse simultaneously

## 📝 Configuration Options

### Permission Levels
```lua
Config.Sharing = {
    permissionLevels = {
        'read',    -- Read-only access
        'write',   -- Read and write access
        'admin'    -- Full access except ownership
    },
    
    defaultPermission = 'read',
    maxSharedUsers = 10,
    allowTemporaryAccess = true,
    maxTemporaryDuration = 24 * 60 * 60, -- 24 hours in seconds
}
```

### UI Customization
```lua
Config.UI = {
    showPermissionLevels = true,
    showExpirationDates = true,
    showOwnerNames = true,
    showAccessTimestamps = false,
    maxWarehousesPerPage = 5
}
```

## 🔄 Migration Strategy

### From Current System
1. **Database Migration**: Add sharing tables without breaking existing functionality
2. **Feature Flag**: Enable sharing system via configuration
3. **Gradual Rollout**: Test with small group before full release
4. **Backward Compatibility**: Ensure existing warehouses continue to work

### Data Migration
- Existing warehouses maintain current ownership
- No data loss during migration
- Optional migration to sharing system
- Rollback capability if issues arise

## 🎯 Next Steps

### Phase 2 Features (Future)
- **Multiple Ownership**: Allow multiple players to own same warehouse
- **Permission Inheritance**: Hierarchical permission systems
- **Access Scheduling**: Time-based access control
- **Advanced Audit Logging**: Detailed access and modification logs

### Phase 3 Features (Future)
- **Warehouse Networks**: Connect multiple warehouses
- **Automated Sharing**: Rules-based access management
- **Mobile Management**: Remote warehouse management
- **Integration APIs**: Connect with other systems

---

*This document outlines the comprehensive warehouse sharing system implementation. The system is designed to be flexible, secure, and user-friendly while maintaining the existing warehouse functionality.*

## 🚀 Quick Start

1. **Install the updated script**
2. **Run the SQL migration** (`sql/warehouse.sql`)
3. **Restart the resource**
4. **Test with two players**:
   - Player A: Buy warehouse and share with Player B
   - Player B: Access shared warehouse
   - Verify permissions work correctly

The sharing system is now fully functional and ready for production use!


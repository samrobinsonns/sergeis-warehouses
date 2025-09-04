# Sergei's Warehouse - Advanced Storage & Sharing System

A comprehensive FiveM warehouse script for QBCore that provides players with personal storage space they can expand and share with other players. Features a modern UI, flexible sharing system, and robust permission management.

## Features

### Core Storage System
- **Single Warehouse Type**: One warehouse per player with expandable storage
- **Simple Storage System**: Purchase additional storage slots to increase capacity
- **Clean UI**: Modern, intuitive interface for managing warehouse and storage
- **Easy Integration**: Simple setup with QBCore
- **Configurable**: Easy to customize prices, locations, and storage limits

### Advanced Sharing System
- **Warehouse Sharing**: Share your warehouse with other players
- **Permission Levels**: Granular access control (Read, Write, Admin)
- **Temporary Access**: Set expiration dates for shared access
- **Player Search**: Find nearby players to share with
- **Access Management**: Easy sharing permissions and user management
- **Multi-Warehouse Access**: Access both owned and shared warehouses

## Installation

1. **Download** the resource to your server's resources folder
2. **Import** the SQL file from `sql/warehouse.sql` to your database
3. **Add** `ensure sergeis-warehouse` to your server.cfg
4. **Restart** your server

## Configuration

Edit `config.lua` to customize:

- **Warehouse Price**: Base cost for the warehouse
- **Slot Price**: Cost per additional storage slot
- **Max Slots**: Maximum number of slots a player can purchase
- **Location**: Sales ped and entrance coordinates
- **Interior**: Warehouse interior location and props

## Usage

### For Players

#### Basic Warehouse Management
1. **Purchase Warehouse**: Visit the sales ped to buy your first warehouse
2. **Buy Storage Slots**: Purchase additional storage slots to expand capacity
3. **Access Storage**: Use the `/warehouse` command or F6 key to open the menu
4. **Enter Warehouse**: Visit the entrance marker to access your warehouse interior

#### Sharing Your Warehouse
1. **Open Sharing Menu**: Use F6 to open warehouse menu, go to "Sharing" tab
2. **Find Players**: System automatically detects nearby players (within 50 meters)
3. **Select Player**: Click on a nearby player to select them
4. **Share Access**: Click "Share Warehouse" (defaults to "Read & Write" permission)
5. **Manage Users**: View and manage all users with access to your warehouse

#### Accessing Shared Warehouses
1. **View Shared Access**: Go to "Shared Access" tab in warehouse menu
2. **Select Warehouse**: Choose from warehouses shared with you
3. **Enter Warehouse**: Access the shared warehouse based on your permission level
4. **Check Permissions**: View your access level (Read, Write, or Admin)

### Permission Levels

- **Read Access**: Can view and take items from storage
- **Write Access**: Can add, remove, and organize items in storage (default for new shares)
- **Admin Access**: Can manage warehouse settings and sharing permissions

### For Admins

- **Command**: `/warehouse` - Opens the warehouse management UI
- **Key Binding**: F6 - Quick access to warehouse menu
- **Permissions**: Uses QBCore player data for ownership
- **Sharing Management**: Full control over warehouse sharing system

## Database Schema

The script creates several tables for comprehensive warehouse management:

### Core Tables
- `warehouses`: Stores warehouse ownership and purchased slot count
- `warehouse_storage`: Stores items in each storage slot

### Sharing System Tables
- `warehouse_sharing`: Manages sharing relationships and permissions
- `warehouse_access_log`: Optional logging for warehouse access (if enabled)

## Dependencies

- **QBCore**: Core framework for player management
- **MySQL**: Database for persistent storage
- **ox_target** (optional): For enhanced interaction system

## Recent Updates

### v2.0 - Sharing System Implementation
- ✅ **Warehouse Sharing**: Share warehouses with other players
- ✅ **Permission Management**: Granular access control system
- ✅ **Player Detection**: Automatic nearby player detection
- ✅ **Simplified UI**: Hidden permission fields with smart defaults
- ✅ **Multi-Access**: Access both owned and shared warehouses
- ✅ **Security**: Server-side validation for all sharing operations

### UI Improvements
- **Simplified Sharing**: Permission and expiration fields are now hidden with smart defaults
- **Default Permissions**: New shares default to "Read & Write" access
- **No Expiration**: Shared access has no expiration by default (permanent access)
- **Cleaner Interface**: Focus on player selection and sharing action

## Use Cases

### Business Operations
- **Crew Management**: Gang leaders can share warehouses with crew members
- **Business Partnerships**: Partners can share access to each other's storage
- **Trading Networks**: Central warehouses shared with multiple traders

### Temporary Access
- **Job Contracts**: Share access for specific operations
- **Event Access**: Temporary sharing for special events
- **Guest Access**: Limited-time access for visitors

## Support

For issues or questions, please check:
1. Database connection and table creation
2. QBCore integration
3. Resource dependencies
4. Console errors
5. Sharing system permissions and access

## Additional Documentation

- **Sharing System**: See `WAREHOUSE_SHARING_SYSTEM.md` for detailed sharing system documentation
- **Configuration**: Edit `config.lua` for customization options
- **Database**: Import `sql/warehouse.sql` for complete database setup

## License

This resource is provided as-is for FiveM server use.



# Sergei's Warehouse - Simplified Storage System

A simplified FiveM warehouse script for QBCore that provides players with personal storage space they can expand by purchasing additional slots.

## Features

- **Single Warehouse Type**: One warehouse per player with expandable storage
- **Simple Storage System**: Purchase additional storage slots to increase capacity
- **Clean UI**: Modern, intuitive interface for managing warehouse and storage
- **Easy Integration**: Simple setup with QBCore
- **Configurable**: Easy to customize prices, locations, and storage limits

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

1. **Purchase Warehouse**: Visit the sales ped to buy your first warehouse
2. **Buy Storage Slots**: Purchase additional storage slots to expand capacity
3. **Access Storage**: Use the `/warehouse` command or F6 key to open the menu
4. **Enter Warehouse**: Visit the entrance marker to access your warehouse interior

### For Admins

- **Command**: `/warehouse` - Opens the warehouse management UI
- **Key Binding**: F6 - Quick access to warehouse menu
- **Permissions**: Uses QBCore player data for ownership

## Database Schema

The script creates two main tables:

- `warehouses`: Stores warehouse ownership and purchased slot count
- `warehouse_storage`: Stores items in each storage slot

## Dependencies

- **QBCore**: Core framework for player management
- **MySQL**: Database for persistent storage
- **ox_target** (optional): For enhanced interaction system

## Support

For issues or questions, please check:
1. Database connection and table creation
2. QBCore integration
3. Resource dependencies
4. Console errors

## License

This resource is provided as-is for FiveM server use.



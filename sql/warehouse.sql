-- Sergei's Warehouse - Simplified Schema
-- This script creates the necessary tables for the simplified warehouse system

-- Create warehouses table (one warehouse per citizen)
CREATE TABLE IF NOT EXISTS `warehouses` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `citizenid` VARCHAR(50) NOT NULL,
    `purchased_slots` INT NOT NULL DEFAULT 0,
    `created_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uniq_owner` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Create warehouse storage table for items
CREATE TABLE IF NOT EXISTS `warehouse_storage` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `warehouse_id` INT NOT NULL,
    `slot_index` INT NOT NULL,
    `item_name` VARCHAR(32) NULL,
    `item_count` INT NOT NULL DEFAULT 0,
    `created_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uniq_slot` (`warehouse_id`,`slot_index`),
    CONSTRAINT `fk_storage_wh` FOREIGN KEY (`warehouse_id`) REFERENCES `warehouses` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Insert sample data (optional)
-- INSERT INTO `warehouses` (`citizenid`, `purchased_slots`) VALUES ('SAMPLE_CITIZEN_ID', 5);
-- INSERT INTO `warehouse_storage` (`warehouse_id`, `slot_index`, `item_name`, `item_count`) VALUES (1, 0, 'bread', 10);



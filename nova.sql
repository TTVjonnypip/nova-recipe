-- Nova framework: every table the framework and bundled scripts need.
-- Safe to run more than once (CREATE TABLE IF NOT EXISTS).

-- ---- from nova_core/sql/nova.sql ----
-- Nova framework schema. Compatible with existing qb-core `players` and `bans` tables,
-- so you can point Nova at a QBCore database without migrating.

CREATE TABLE IF NOT EXISTS `players` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `citizenid` varchar(50) NOT NULL,
  `cid` int(11) DEFAULT NULL,
  `license` varchar(255) NOT NULL,
  `name` varchar(255) NOT NULL,
  `money` text NOT NULL,
  `charinfo` text DEFAULT NULL,
  `job` text NOT NULL,
  `gang` text DEFAULT NULL,
  `position` text NOT NULL,
  `metadata` text NOT NULL,
  `inventory` longtext DEFAULT NULL,
  `last_updated` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `last_logged_out` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`citizenid`),
  KEY `id` (`id`),
  KEY `last_updated` (`last_updated`),
  KEY `license` (`license`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `bans` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(50) DEFAULT NULL,
  `license` varchar(50) DEFAULT NULL,
  `discord` varchar(50) DEFAULT NULL,
  `ip` varchar(50) DEFAULT NULL,
  `reason` text DEFAULT NULL,
  `expire` int(11) DEFAULT NULL,
  `bannedby` varchar(255) NOT NULL DEFAULT 'Console',
  PRIMARY KEY (`id`),
  KEY `license` (`license`),
  KEY `discord` (`discord`),
  KEY `ip` (`ip`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


-- ---- from nova_core/sql/player_vehicles.sql ----
-- Owned vehicles. Used by fp-dealership, qbx_easygarage, qbx_starterpack and nova_phone.
-- Same layout as qb-core / Qbox, so an existing player_vehicles table works as-is.

CREATE TABLE IF NOT EXISTS `player_vehicles` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `license` varchar(50) DEFAULT NULL,
  `citizenid` varchar(50) DEFAULT NULL,
  `vehicle` varchar(50) DEFAULT NULL,
  `hash` varchar(50) DEFAULT NULL,
  `mods` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL,
  `plate` varchar(15) NOT NULL,
  `fakeplate` varchar(50) DEFAULT NULL,
  `garage` varchar(50) DEFAULT NULL,
  `fuel` int(11) DEFAULT 100,
  `engine` float DEFAULT 1000,
  `body` float DEFAULT 1000,
  `state` int(11) DEFAULT 1,
  `depotprice` int(11) NOT NULL DEFAULT 0,
  `drivingdistance` int(50) DEFAULT NULL,
  `status` text DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `plate` (`plate`),
  KEY `citizenid` (`citizenid`),
  KEY `license` (`license`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


-- ---- from custom_inventory/sql/install.sql ----
CREATE TABLE IF NOT EXISTS `inventories` (
    `id`         VARCHAR(120) NOT NULL,
    `data`       LONGTEXT     NOT NULL,
    `updated_at` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


-- ---- from nova_phone/sql/install.sql ----
-- Nova Phone tables. Run once on your server database.

CREATE TABLE IF NOT EXISTS `phone_contacts` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `citizenid` VARCHAR(50) NOT NULL,
  `name` VARCHAR(50) NOT NULL,
  `number` VARCHAR(20) NOT NULL,
  `created` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX (`citizenid`)
);

CREATE TABLE IF NOT EXISTS `phone_messages` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `sender` VARCHAR(20) NOT NULL,
  `receiver` VARCHAR(20) NOT NULL,
  `message` TEXT NOT NULL,
  `is_read` TINYINT(1) DEFAULT 0,
  `created` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX (`sender`),
  INDEX (`receiver`)
);

CREATE TABLE IF NOT EXISTS `phone_calls` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `caller` VARCHAR(20) NOT NULL,
  `receiver` VARCHAR(20) NOT NULL,
  `status` VARCHAR(16) NOT NULL DEFAULT 'missed',
  `created` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX (`caller`),
  INDEX (`receiver`)
);

CREATE TABLE IF NOT EXISTS `phone_bank_log` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `citizenid` VARCHAR(50) NOT NULL,
  `label` VARCHAR(100) NOT NULL,
  `amount` INT NOT NULL,
  `created` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX (`citizenid`)
);

CREATE TABLE IF NOT EXISTS `phone_chirps` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `citizenid` VARCHAR(50) NOT NULL,
  `author` VARCHAR(60) NOT NULL,
  `handle` VARCHAR(40) NOT NULL,
  `content` VARCHAR(400) NOT NULL,
  `likes` INT DEFAULT 0,
  `created` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS `phone_chirp_likes` (
  `chirp_id` INT NOT NULL,
  `citizenid` VARCHAR(50) NOT NULL,
  PRIMARY KEY (`chirp_id`, `citizenid`)
);

CREATE TABLE IF NOT EXISTS `phone_ads` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `citizenid` VARCHAR(50) NOT NULL,
  `author` VARCHAR(60) NOT NULL,
  `number` VARCHAR(20) NOT NULL,
  `title` VARCHAR(80) NOT NULL,
  `body` VARCHAR(500) NOT NULL,
  `price` INT DEFAULT NULL,
  `created` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS `phone_mail` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `citizenid` VARCHAR(50) NOT NULL,
  `sender` VARCHAR(80) NOT NULL,
  `subject` VARCHAR(120) NOT NULL,
  `body` TEXT NOT NULL,
  `is_read` TINYINT(1) DEFAULT 0,
  `created` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX (`citizenid`)
);

CREATE TABLE IF NOT EXISTS `phone_notes` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `citizenid` VARCHAR(50) NOT NULL,
  `title` VARCHAR(80) NOT NULL,
  `body` TEXT NOT NULL,
  `updated` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX (`citizenid`)
);

CREATE TABLE IF NOT EXISTS `phone_settings` (
  `citizenid` VARCHAR(50) PRIMARY KEY,
  `wallpaper` VARCHAR(20) DEFAULT 'aurora',
  `muted` TINYINT(1) DEFAULT 0
);


-- ---- from qbx_marriage/marriage.sql ----
CREATE TABLE IF NOT EXISTS `marriages` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `partner1` VARCHAR(50) NOT NULL,
    `partner2` VARCHAR(50) NOT NULL,
    `partner1_name` VARCHAR(100) NOT NULL,
    `partner2_name` VARCHAR(100) NOT NULL,
    `status` ENUM('engaged', 'married', 'divorced', 'cancelled') NOT NULL DEFAULT 'engaged',
    `engaged_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `married_at` TIMESTAMP NULL DEFAULT NULL,
    `ended_at` TIMESTAMP NULL DEFAULT NULL,
    PRIMARY KEY (`id`),
    KEY `partner1` (`partner1`),
    KEY `partner2` (`partner2`),
    KEY `status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


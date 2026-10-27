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

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

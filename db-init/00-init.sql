-- Ensure root can connect from any container host and has the right password
CREATE USER IF NOT EXISTS 'root'@'%' IDENTIFIED BY 'SuperRoot123!';
GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' WITH GRANT OPTION;

-- Ensure the app DB + user exist and can connect from containers
CREATE DATABASE IF NOT EXISTS `testlinkdb` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS 'tluser'@'%' IDENTIFIED BY 'TLpass123!';
GRANT ALL PRIVILEGES ON `testlinkdb`.* TO 'tluser'@'%';

FLUSH PRIVILEGES;

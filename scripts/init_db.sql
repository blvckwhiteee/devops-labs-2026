CREATE DATABASE IF NOT EXISTS mywebapp_db;
CREATE USER IF NOT EXISTS 'user'@'127.0.0.1' IDENTIFIED BY 'password';
CREATE USER IF NOT EXISTS 'user'@'localhost' IDENTIFIED BY 'password';
GRANT ALL PRIVILEGES ON mywebapp_db.* TO 'user'@'127.0.0.1';
GRANT ALL PRIVILEGES ON mywebapp_db.* TO 'user'@'localhost';
FLUSH PRIVILEGES;
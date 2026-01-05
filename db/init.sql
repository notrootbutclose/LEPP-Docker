-- Создание дополнительной базы данных для тестов
CREATE DATABASE IF NOT EXISTS test_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Создание пользователя для мониторинга (для экспортера)
CREATE USER IF NOT EXISTS 'exporter'@'%' IDENTIFIED BY 'exporterpass123';

-- Предоставление необходимых привилегий для мониторинга
GRANT PROCESS, REPLICATION CLIENT ON *.* TO 'exporter'@'%';
GRANT SELECT ON performance_schema.* TO 'exporter'@'%';
GRANT SELECT ON mysql.* TO 'exporter'@'%';

-- Применение изменений
FLUSH PRIVILEGES;

-- Пример создания таблицы
USE lempdb;

CREATE TABLE IF NOT EXISTS users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    email VARCHAR(100) NOT NULL UNIQUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Вставка тестовых данных
INSERT INTO users (username, email) VALUES
('admin', 'admin@example.com'),
('user1', 'user1@example.com'),
('user2', 'user2@example.com')
ON DUPLICATE KEY UPDATE updated_at = CURRENT_TIMESTAMP;

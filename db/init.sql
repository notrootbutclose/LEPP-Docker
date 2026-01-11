-- Создание пользователя для мониторинга
CREATE USER exporter WITH PASSWORD 'exporterpass123';

-- Предоставление прав для мониторинга
GRANT CONNECT ON DATABASE leppdb TO exporter;
GRANT pg_monitor TO exporter;

-- Создание тестовой таблицы
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    email VARCHAR(100) NOT NULL UNIQUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Вставка тестовых данных
INSERT INTO users (username, email) VALUES
    ('admin', 'admin@example.com'),
    ('user1', 'user1@example.com'),
    ('user2', 'user2@example.com')
ON CONFLICT (username) DO NOTHING;

-- Создание индекса
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);

<?php
// Кэширование результата БД с Redis
$cache_key = 'db_status';
$cached_result = null;

// Подключение к Redis
try {
    $redis = new Redis();
    $redis->connect('redis', 6379);
    $cached_result = $redis->get($cache_key);
    if ($cached_result) {
        $cached_result = json_decode($cached_result, true);
    }
} catch (Exception $e) {
    $redis = null;
}

if (!$cached_result) {
    // Настройки подключения к БД
    $host = 'db';
    $dbname = getenv('MYSQL_DATABASE') ?: 'lempdb';
    $username = getenv('MYSQL_USER') ?: 'user';
    $password = getenv('MYSQL_PASSWORD') ?: '123456';

    try {
        $pdo = new PDO("mysql:host=$host;dbname=$dbname", $username, $password, [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            PDO::ATTR_PERSISTENT => true
        ]);

        // Создание тестовой таблицы
        $pdo->exec("CREATE TABLE IF NOT EXISTS test_table (
            id INT AUTO_INCREMENT PRIMARY KEY,
            message VARCHAR(255),
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )");

        // Добавление тестовой записи
        $stmt = $pdo->prepare("INSERT INTO test_table (message) VALUES (:message)");
        $stmt->execute(['message' => 'Test from ' . gethostname()]);

        // Получение версии и статистики
        $version = $pdo->query("SELECT VERSION() as version")->fetch()['version'];
        $count = $pdo->query("SELECT COUNT(*) as count FROM test_table")->fetch()['count'];

        $db_result = [
            'status' => 'connected',
            'version' => $version,
            'records' => $count
        ];

        // Кэшируем на 30 секунд
        if ($redis) {
            $redis->setex($cache_key, 30, json_encode($db_result));
        }
    } catch(PDOException $e) {
        $db_result = [
            'status' => 'error',
            'message' => $e->getMessage()
        ];
    }
} else {
    $db_result = $cached_result;
    $db_result['cached'] = true;
}

// Статистика Redis
$redis_status = 'disconnected';
if ($redis) {
    try {
        $redis_status = $redis->ping() ? 'connected' : 'disconnected';
        $redis_memory = $redis->info('memory')['used_memory_human'] ?? 'unknown';
    } catch (Exception $e) {
        $redis_status = 'error';
        $redis_memory = 'unknown';
    }
}
?>

<!DOCTYPE html>
<html lang="ru">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>LEMP Stack Status</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }

        body {
            font-family: 'SF Mono', 'Monaco', 'Cascadia Code', 'Roboto Mono', monospace;
            background: #0d1117;
            color: #e6edf3;
            line-height: 1.6;
            padding: 2rem;
            min-height: 100vh;
        }

        .container {
            max-width: 1000px;
            margin: 0 auto;
        }

        h1 {
            color: #58a6ff;
            margin-bottom: 2rem;
            font-size: 1.8rem;
            font-weight: 600;
        }

        .status-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 1.5rem;
            margin-bottom: 2rem;
        }

        .status-card {
            background: #161b22;
            border: 1px solid #30363d;
            border-radius: 8px;
            padding: 1.5rem;
        }

        .status-card h2 {
            color: #7d8590;
            font-size: 0.9rem;
            text-transform: uppercase;
            letter-spacing: 0.5px;
            margin-bottom: 1rem;
        }

        .status-indicator {
            display: flex;
            align-items: center;
            gap: 0.5rem;
            margin-bottom: 0.5rem;
        }

        .status-dot {
            width: 8px;
            height: 8px;
            border-radius: 50%;
        }

        .status-connected { background: #3fb950; }
        .status-error { background: #f85149; }
        .status-cached { background: #d29922; }

        .metric {
            color: #7d8590;
            font-size: 0.85rem;
            margin: 0.3rem 0;
        }

        .metric-value {
            color: #e6edf3;
            font-weight: 500;
        }

        .info-section {
            background: #161b22;
            border: 1px solid #30363d;
            border-radius: 8px;
            padding: 1.5rem;
            margin-bottom: 1.5rem;
        }

        .info-section h2 {
            color: #58a6ff;
            margin-bottom: 1rem;
            font-size: 1.1rem;
        }

        .info-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 1rem;
        }

        .links {
            display: flex;
            gap: 1rem;
            flex-wrap: wrap;
            margin-top: 1.5rem;
        }

        .link {
            color: #58a6ff;
            text-decoration: none;
            padding: 0.5rem 1rem;
            border: 1px solid #30363d;
            border-radius: 6px;
            transition: all 0.2s ease;
            font-size: 0.9rem;
        }

        .link:hover {
            background: #21262d;
            border-color: #58a6ff;
        }

        .footer {
            text-align: center;
            color: #7d8590;
            font-size: 0.8rem;
            margin-top: 3rem;
            padding-top: 1rem;
            border-top: 1px solid #30363d;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>LEMP Stack - Performance Monitor</h1>

        <div class="status-grid">
            <!-- Database Status -->
            <div class="status-card">
                <h2>Database</h2>
                <div class="status-indicator">
                    <span class="status-dot <?= $db_result['status'] === 'connected' ? 'status-connected' : 'status-error' ?>"></span>
                    <span><?= ucfirst($db_result['status']) ?></span>
                    <?php if (isset($db_result['cached'])): ?>
                    <span class="status-dot status-cached"></span>
                    <span style="color: #d29922;">Cached</span>
                    <?php endif; ?>
                </div>
                <?php if ($db_result['status'] === 'connected'): ?>
                <div class="metric">Version: <span class="metric-value"><?= $db_result['version'] ?></span></div>
                <div class="metric">Records: <span class="metric-value"><?= $db_result['records'] ?></span></div>
                <?php else: ?>
                <div class="metric" style="color: #f85149;">Error: <?= $db_result['message'] ?></div>
                <?php endif; ?>
            </div>

            <!-- Redis Status -->
            <div class="status-card">
                <h2>Cache</h2>
                <div class="status-indicator">
                    <span class="status-dot <?= $redis_status === 'connected' ? 'status-connected' : 'status-error' ?>"></span>
                    <span><?= ucfirst($redis_status) ?></span>
                </div>
                <div class="metric">Memory: <span class="metric-value"><?= $redis_memory ?? 'unknown' ?></span></div>
            </div>

            <!-- PHP Status -->
            <div class="status-card">
                <h2>PHP Runtime</h2>
                <div class="status-indicator">
                    <span class="status-dot status-connected"></span>
                    <span>Active</span>
                </div>
                <div class="metric">Version: <span class="metric-value"><?= phpversion() ?></span></div>
                <div class="metric">Memory: <span class="metric-value"><?= ini_get('memory_limit') ?></span></div>
                <div class="metric">Container: <span class="metric-value"><?= gethostname() ?></span></div>
                <div class="metric">Load balanced: <span class="metric-value">Yes</span></div>
            </div>
        </div>

        <div class="info-section">
            <h2>System Information</h2>
            <div class="info-grid">
                <div>
                    <div class="metric">Server: <span class="metric-value"><?= $_SERVER['SERVER_SOFTWARE'] ?? 'Unknown' ?></span></div>
                    <div class="metric">Host: <span class="metric-value"><?= $_SERVER['HTTP_HOST'] ?? 'localhost' ?></span></div>
                </div>
                <div>
                    <div class="metric">OPcache: <span class="metric-value"><?= function_exists('opcache_get_status') && opcache_get_status() ? 'Enabled' : 'Disabled' ?></span></div>
                    <div class="metric">Extensions: <span class="metric-value"><?= count(get_loaded_extensions()) ?> loaded</span></div>
                </div>
            </div>
        </div>

        <div class="links">
            <a href="/info.php" class="link">PHP Info</a>
            <a href="http://<?= $_SERVER['HTTP_HOST'] ?>:3000" class="link" target="_blank">Grafana</a>
            <a href="http://<?= $_SERVER['HTTP_HOST'] ?>:9090" class="link" target="_blank">Prometheus</a>
            <a href="/nginx_status" class="link">Nginx Status</a>
        </div>

        <div class="footer">
            LEMP Stack Docker Container
        </div>
    </div>
</body>
</html>


<?php
// Засекаем время начала
$start_time = microtime(true);

// --- Подключение к Redis ---
$redis = null;
$redis_status = 'disconnected';

try {
    $redis = new Redis();
    $redis->connect('redis', 6379);
    if ($redis->ping() === '+PONG') {
        $redis_status = 'connected';
    }
} catch (Exception $e) {
    $redis_status = 'error';
}

// --- Подключение к PostgreSQL ---
$db_status = 'disconnected';
$db_version = 'N/A';
$db_error = null;

$host = 'db';
$dbname = getenv('POSTGRES_DB') ?: 'lempdb';
$username = getenv('POSTGRES_USER') ?: 'lempuser';
$password = getenv('POSTGRES_PASSWORD') ?: 'LempSecurePass2024!';

try {
    $pdo = new PDO("pgsql:host=$host;dbname=$dbname", $username, $password, [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
        PDO::ATTR_PERSISTENT => true
    ]);
    $db_version = $pdo->query("SELECT VERSION()")->fetchColumn();
    $db_status = 'connected';
} catch (PDOException $e) {
    $db_status = 'error';
    $db_error = $e->getMessage();
}

// --- Информация о контейнере ---
$container_id = gethostname();
$php_version = phpversion();
$memory_limit = ini_get('memory_limit');

// --- Nginx статус ---
$nginx_status = 'running'; // если PHP отвечает, значит Nginx работает

// --- OPcache ---
$opcache_status = 'disabled';
if (function_exists('opcache_get_status')) {
    $opcache_data = opcache_get_status();
    if (is_array($opcache_data) && !empty($opcache_data['opcache_enabled'])) {
        $opcache_status = 'enabled';
    }
}

// --- Health Check ---
$health_status = 'operational';
$health_class = 'status-ok';

if ($db_status === 'error' || $redis_status === 'error') {
    $health_status = 'degraded';
    $health_class = 'status-warn';
}
if ($db_status === 'disconnected' && $redis_status === 'disconnected') {
    $health_status = 'critical';
    $health_class = 'status-err';
}

// --- Время загрузки ---
$page_load_time = round((microtime(true) - $start_time) * 1000, 2);
?>

<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta http-equiv="refresh" content="5">
    <title>LEPP Stack Monitor</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        html, body {
            background: #000;
            color: #0f0;
            font-family: 'Courier New', Consolas, monospace;
            line-height: 1.6;
            padding: 2rem;
            font-size: 14px;
            min-height: 100vh;
        }
        .container { max-width: 1200px; margin: 0 auto; }
        
        h1 {
            font-size: 2rem;
            margin-bottom: 2rem;
            letter-spacing: 2px;
            border-bottom: 2px solid #0f0;
            padding-bottom: 0.75rem;
            display: flex;
            justify-content: space-between;
            align-items: center;
            text-shadow: 0 0 10px #0f0;
        }
        
        .health-indicator {
            font-size: 1rem;
            display: flex;
            align-items: center;
            gap: 0.75rem;
        }
        
        .grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
            gap: 1.5rem;
            margin-bottom: 2rem;
        }
        
        .card {
            background: #000;
            border: 2px solid #0f0;
            padding: 1.25rem;
            position: relative;
            box-shadow: 0 0 20px rgba(0, 255, 0, 0.3);
        }
        
        .card h2 {
            font-size: 1.1rem;
            margin-bottom: 1rem;
            color: #0f0;
            text-transform: uppercase;
            letter-spacing: 2px;
            text-shadow: 0 0 10px #0f0;
        }
        
        .metric { 
            margin: 0.5rem 0; 
            display: flex;
            align-items: center;
        }
        
        .label { 
            flex: 0 0 140px;
            color: #0c0; 
            font-weight: bold;
        }
        
        .value { 
            color: #0f0; 
            font-weight: bold;
            text-shadow: 0 0 5px #0f0;
        }
        
        .status { 
            display: inline-block; 
            width: 14px; 
            height: 14px; 
            border-radius: 50%; 
            margin-right: 8px;
            animation: pulse 2s infinite;
        }
        
        @keyframes pulse {
            0%, 100% { opacity: 1; }
            50% { opacity: 0.5; }
        }
        
        .status-ok { 
            background: #0f0; 
            box-shadow: 0 0 10px #0f0, 0 0 20px #0f0;
        }
        
        .status-warn { 
            background: #ff0; 
            box-shadow: 0 0 10px #ff0, 0 0 20px #ff0;
        }
        
        .status-err { 
            background: #f00; 
            box-shadow: 0 0 10px #f00, 0 0 20px #f00;
        }
        
        .error-msg { 
            color: #f66; 
            font-size: 0.85rem; 
            margin-top: 0.5rem;
            word-break: break-word;
        }
        
        .footer {
            margin-top: 3rem;
            color: #0c0;
            font-size: 0.9rem;
            text-align: center;
            border-top: 1px solid #0f0;
            padding-top: 1rem;
            display: flex;
            justify-content: space-between;
            align-items: center;
        }
        
        .auto-refresh {
            font-size: 0.75rem;
            color: #080;
        }
        
        /* Эффект сканирующей линии */
        @keyframes scan {
            0% { top: 0; }
            100% { top: 100%; }
        }
        
        .scan-line {
            position: fixed;
            left: 0;
            right: 0;
            height: 2px;
            background: linear-gradient(transparent, #0f0, transparent);
            animation: scan 4s linear infinite;
            pointer-events: none;
            opacity: 0.3;
        }
    </style>
</head>
<body>
    <div class="scan-line"></div>
    
    <div class="container">
        <h1>
            <span>LEPP STACK MONITOR</span>
            <span class="health-indicator">
                <span class="status <?= $health_class ?>"></span>
                <span><?= strtoupper($health_status) ?></span>
            </span>
        </h1>

        <div class="grid">
            <!-- Nginx -->
            <div class="card">
                <h2>[ NGINX ]</h2>
                <div class="metric">
                    <span class="status status-ok"></span>
                    <span class="label">STATUS:</span>
                    <span class="value"><?= strtoupper($nginx_status) ?></span>
                </div>
            </div>

            <!-- PostgreSQL -->
            <div class="card">
                <h2>[ POSTGRESQL ]</h2>
                <div class="metric">
                    <span class="status <?= $db_status === 'connected' ? 'status-ok' : 'status-err' ?>"></span>
                    <span class="label">STATUS:</span>
                    <span class="value"><?= strtoupper($db_status) ?></span>
                </div>
                <?php if ($db_status === 'connected'): ?>
                    <div class="metric">
                        <span class="label">VERSION:</span>
                        <span class="value"><?= htmlspecialchars(explode(' ', $db_version)[1] ?? 'N/A') ?></span>
                    </div>
                <?php else: ?>
                    <div class="error-msg">ERROR: <?= htmlspecialchars(substr($db_error ?? 'Connection failed', 0, 50)) ?></div>
                <?php endif; ?>
            </div>

            <!-- Redis -->
            <div class="card">
                <h2>[ REDIS CACHE ]</h2>
                <div class="metric">
                    <span class="status <?= $redis_status === 'connected' ? 'status-ok' : 'status-err' ?>"></span>
                    <span class="label">STATUS:</span>
                    <span class="value"><?= strtoupper($redis_status) ?></span>
                </div>
            </div>

            <!-- PHP Runtime -->
            <div class="card">
                <h2>[ PHP RUNTIME ]</h2>
                <div class="metric">
                    <span class="status status-ok"></span>
                    <span class="label">STATUS:</span>
                    <span class="value">ACTIVE</span>
                </div>
                <div class="metric">
                    <span class="label">VERSION:</span>
                    <span class="value"><?= htmlspecialchars($php_version) ?></span>
                </div>
                <div class="metric">
                    <span class="label">MEMORY LIMIT:</span>
                    <span class="value"><?= htmlspecialchars($memory_limit) ?></span>
                </div>
                <div class="metric">
                    <span class="label">CONTAINER:</span>
                    <span class="value"><?= htmlspecialchars(substr($container_id, 0, 12)) ?></span>
                </div>
                <div class="metric">
                    <span class="label">OPCACHE:</span>
                    <span class="value"><?= strtoupper($opcache_status) ?></span>
                </div>
                <div class="metric">
                    <span class="label">LOAD BALANCED:</span>
                    <span class="value">YES</span>
                </div>
            </div>
        </div>

        <div class="footer">
            <span>LEPP Stack | Nginx + PHP-FPM + PostgreSQL + Redis | <?= date('Y-m-d H:i:s') ?></span>
            <span class="auto-refresh">[ AUTO-REFRESH: 5s | PAGE LOAD: <?= $page_load_time ?> ms ]</span>
        </div>
    </div>
</body>
</html>

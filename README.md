LEMP Stack in Docker with Full Observability

[![Docker](https://img.shields.io/badge/Docker-20.10%2B-2496ED?logo=docker&logoColor=white&style=flat-square)](https://docs.docker.com/)
[![PHP](https://img.shields.io/badge/PHP-8.2-777BB4?logo=php&logoColor=white&style=flat-square)](https://www.php.net/)
[![Nginx](https://img.shields.io/badge/Nginx-Alpine-009639?logo=nginx&logoColor=white&style=flat-square)](https://nginx.org/)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-15-336791?logo=postgresql&logoColor=white)](https://www.postgresql.org/)
[![Prometheus](https://img.shields.io/badge/Prometheus-Latest-E6522C?logo=prometheus&logoColor=white&style=flat-square)](https://prometheus.io/)
[![Grafana](https://img.shields.io/badge/Grafana-Latest-F46800?logo=grafana&logoColor=white&style=flat-square)](https://grafana.com/)

Project Features

   - High Availability: Nginx as a reverse proxy with load balancing across two PHP-FPM instances 
   - Performance: Redis for session caching, PHP OPcache, Nginx FastCGI cache
   - Full Observability:
        Metrics: Prometheus + exporters for all components  
        Visualization: Grafana with preconfigured dashboards  
        Logs: Loki + Promtail for centralized log collection
   - Security: Isolated network, minimal privileges, closed ports 
   - Production-ready: Health checks, auto-restart, optimized configurations

Requirements

    Docker 20.10+  
    Docker Compose v2  
    4 GB minimum (2 GB may work for demo, but not recommended)  
    CPU 2+ cores
    Disk: 10 GB free space (SSD preferred)  

```text
lepp-docker/
├── www/               # Web-files (index.php)
├── app/               # Config PHP-FPM
├── reverse-proxy/     # Config Nginx
├── db/                # Init PostgreSQL
├── prometheus/        # Config Prometheus
├── grafana/           # Dashboards and datasources
└── .env               # env variables
```

 1. Internet → Nginx (reverse proxy)
    Users from the internet access your service via a domain name or IP address.
    Nginx acts as a reverse proxy:  
        Receives HTTP/HTTPS requests from clients.  
        Forwards them to internal services (in this case, PHP-FPM).  
        Can also cache static files, handle SSL/TLS termination, rate-limit requests, etc.
2. Nginx → PHP-FPM (x2)
    Dynamic requests (e.g., /index.php) are passed by Nginx to PHP-FPM (FastCGI Process Manager for PHP).
    You have two PHP-FPM instances (horizontal scaling):  
        This improves fault tolerance and scalability.  
        Nginx can distribute load between them (e.g., using an upstream block in its configuration).
        The PHP application:  
        Handles business logic.  
        Reads/writes data to PostgreSQL.  
        Stores sessions in Redis (instead of on local disk—faster and more scalable).
3. PHP-FPM → PostgreSQL
    PostgreSQL is a powerful, open-source relational database management system.
    The PHP application connects to it to store and retrieve structured data: users, posts, orders, etc.
    It’s important to use connection pooling, prepared statements, and proper access privileges for security and performance.
4. Redis (sessions)
    Redis is an in-memory data store with extremely high read/write speed.
    Here, it’s used exclusively for sessions:  
        When a user logs in, their session (e.g., PHPSESSID) is stored in Redis.  
        This allows multiple PHP-FPM instances to share session state—users won’t be logged out even if their next request is handled by a different PHP process.
        Benefit: scalable and independent of any single server’s filesystem.
5. Monitoring: Exporters → Prometheus → Grafana
    Exporters (e.g., node_exporter, php-fpm_exporter, postgres_exporter) are lightweight agents that:  
        Collect metrics (CPU, RAM, PHP-FPM request rates, slow PostgreSQL queries, etc.).  
        Expose them over HTTP in a format Prometheus understands.
        Prometheus:  
        Periodically scrapes these endpoints.  
        Stores time-series metrics.
        Grafana:  
        Connects to Prometheus as a data source.  
        Visualizes metrics in intuitive dashboards (CPU usage graphs, PHP response times, query latency, etc.).
6. Logging: Promtail → Loki → Grafana
    Promtail:  
        An agent running on each container that reads log files (e.g., /var/log/php-fpm.log, /var/log/nginx/access.log).  
        Ships them to Loki.
        Loki:  
        A log aggregation system by Grafana Labs.  
        Optimized for label-based indexing rather than full-text indexing (unlike Elasticsearch).  
        Lightweight and resource-efficient.
        Grafana can also connect to Loki, allowing you to:  
        View metrics and logs in a single interface.  
        Click on a spike in a graph → instantly see related logs.

Quick start(Ubuntu/Debian)

Update the system
sudo apt update && sudo apt upgrade -y

Install dependencies
sudo apt install -y ca-certificates curl gnupg lsb-release

Add Docker's GPG key
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
  sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

Add the Docker repository
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

Install Docker
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

Add your user to the docker group
sudo usermod -aG docker $USER
newgrp docker

Verify installation
docker version && docker compose version


Project Deployment

Clone the repository
git clone https://github.com/notrootbutclose/lepp-docker.git
cd lepp-docker

Configure environment variables
cp .env.example .env
nano .env  # SET STRONG PASSWORDS!

Start all services
docker compose up -d --build

Check service status
docker compose ps


Project Structure

```text
lepp-docker/
├── README.md                   # Project overview and instructions
├── LICENSE
├── docker-compose.yml          # Main configuration (includes postgres-exporter)
├── .env.example                # Environment template 
├── .gitignore                  # Git ignore rules
│
├── reverse-proxy/              # Nginx reverse proxy
│   └── nginx.conf
│
├── app/                        # PHP-FPM application
│   ├── Dockerfile
│   └── php-fpm.d/
│       └── www.conf
│
├── www/                        # PHP applications
│   ├── index.php
│   └── info.php
│
├── db/                         # PostgreSQL initialization
│   └── init.sql
│
├── prometheus/                 # Prometheus configuration
│   └── prometheus.yml
│
├── loki/                       # Loki configuration
│   └── loki-config.yml
│
├── promtail/                   # Promtail configuration
│   └── promtail-config.yml
│
└── grafana/                    # Grafana provisioning
    ├── dashboards/
    └── datasources/
        └── datasources.yml
```


Management

Start all services  
docker compose up -d 

Stop services  
docker compose down

View logs  
docker compose logs -f

View logs for a specific service  
docker compose logs -f reverse-proxy

Restart a service  
docker compose restart app-php-1 

Enter a container  
docker exec -it lepp-app-php-1 sh

Monitor resource usage  
docker stats

Full cleanup (including volumes)  
docker compose down -v


Scaling PHP-FPM

Scale to 4 instances  
docker compose up -d --scale app-php-1=2 --scale app-php-2=2 

Or scale to 6 instances  
docker compose up -d --scale app-php-1=3 --scale app-php-2=3 


Created to demonstrate DevOps and containerization skills.

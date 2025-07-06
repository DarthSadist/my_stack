# Cloud-Local n8n & Flowise Setup

Automated installation script for n8n and Flowise with reverse proxy server Caddy for secure access via HTTPS. Optionally includes Prometheus and Grafana monitoring, PostgreSQL database, and Redis cache.

## Description

This repository contains scripts for automatic configuration of:

- **n8n** - a powerful open-source workflow automation platform
- **Flowise** - a tool for creating customizable AI flows
- **Caddy** - a modern web server with automatic HTTPS
- **PostgreSQL** (optional) - persistent database for n8n and Flowise
- **Redis** (optional) - caching and queue management for better performance
- **Adminer** (optional) - web-based database management tool
- **Qdrant** (optional) - vector database for similarity search and AI applications
- **Prometheus & Grafana** (optional) - a monitoring system for metrics collection and visualization

The system is configured to work with your domain name and automatically obtains Let's Encrypt SSL certificates.

## Requirements

- Ubuntu 22.04 
- Domain name pointing to your server's IP address
- Server access with administrator rights (sudo)
- Open ports 80, 443 

## Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/miolamio/cloud-local-n8n-flowise.git && cd cloud-local-n8n-flowise
   ```

2. Make the script executable:
   ```bash
   chmod +x setup.sh
   ```

3. Run the installation script:
   ```bash
   ./setup.sh
   ```

4. Follow the instructions in the terminal:
   - Enter your domain name (e.g., example.com)
   - Enter your email (will be used for n8n login and Let's Encrypt)
   - Choose whether to install the monitoring system (Prometheus + Grafana)
   - Choose whether to install PostgreSQL database
   - Choose whether to install Redis cache
   - Choose whether to install Adminer (for database management)
   - Choose whether to install Qdrant vector database

## What the installation script does

1. **System update** - updates the package list and installs necessary dependencies
2. **Docker installation** - installs Docker Engine and Docker Compose
3. **Directory setup** - creates n8n user and necessary directories
4. **Secret generation** - creates random passwords and encryption keys
5. **Template creation** - generates Docker Compose files from templates
6. **Firewall setup** - opens necessary ports
7. **Service launch** - starts Docker containers
8. **Monitoring setup** (optional) - configures Prometheus and Grafana
9. **Database setup** (if enabled) - configures PostgreSQL and Redis
10. **Adminer setup** (if enabled) - configures database management interface
11. **Qdrant setup** (if enabled) - configures vector database

## Accessing services

After installation completes, you will be able to access services at the following URLs:

- **n8n**: https://n8n.yourdomain.com (replace yourdomain.com with your actual domain)
- **Flowise**: https://flowise.yourdomain.com
- **Adminer** (if installed): https://adminer.yourdomain.com
- **Qdrant** (if installed): https://qdrant.yourdomain.com

If you chose to install the monitoring system:

- **Grafana**: https://grafana.your-domain.xxx
- **Prometheus**: https://prometheus.your-domain.xxx

Login credentials for all services will be displayed at the end of the installation process.

## Project structure

- `setup.sh` - main installation script
- `setup-files/` - directory with helper scripts:
  - `01-update-system.sh` - system update
  - `02-install-docker.sh` - Docker installation
  - `03-setup-directories.sh` - directory and user setup
  - `04-generate-secrets.sh` - secret key generation
  - `05-create-templates.sh` - configuration file creation
  - `06-setup-firewall.sh` - firewall setup
  - `07-start-services.sh` - service launch
  - `backup.sh` - script for backing up n8n and Flowise data
  - `update.sh` - script for updating Docker containers
- `n8n-docker-compose.yaml.template` - docker-compose template for n8n and Caddy
- **flowise-docker-compose.yaml.template** - docker-compose template for Flowise
- **prometheus-docker-compose.yaml.template** - docker-compose template for Prometheus and Grafana (if monitoring is enabled)
- **database-docker-compose.yaml.template** - docker-compose template for PostgreSQL and Redis (if database is enabled)
- **adminer-docker-compose.yaml.template** - docker-compose template for Adminer (if database management is enabled)
- **qdrant-docker-compose.yaml.template** - docker-compose template for Qdrant vector database (if enabled)

## Managing services

### Restarting services

```bash
docker compose -f n8n-docker-compose.yaml restart
docker compose -f flowise-docker-compose.yaml restart
# If monitoring is installed
docker compose -f prometheus-docker-compose.yaml restart
# If database is installed
docker compose -f database-docker-compose.yaml restart
# If Adminer is installed
docker compose -f adminer-docker-compose.yaml restart
# If Qdrant is installed
docker compose -f qdrant-docker-compose.yaml restart
```

### Stopping services

```bash
docker compose -f n8n-docker-compose.yaml down
docker compose -f flowise-docker-compose.yaml down
# If monitoring is installed
docker compose -f prometheus-docker-compose.yaml down
# If database is installed
docker compose -f database-docker-compose.yaml down
# If Adminer is installed
docker compose -f adminer-docker-compose.yaml down
# If Qdrant is installed
docker compose -f qdrant-docker-compose.yaml down
```

### Viewing logs

```bash
docker compose -f n8n-docker-compose.yaml logs
docker compose -f flowise-docker-compose.yaml logs
# If monitoring is installed
docker compose -f prometheus-docker-compose.yaml logs
# If database is installed
docker compose -f database-docker-compose.yaml logs
# If Adminer is installed
docker compose -f adminer-docker-compose.yaml logs
# If Qdrant is installed
docker compose -f qdrant-docker-compose.yaml logs
```

## Security

- All services are accessible only via HTTPS with automatically renewed Let's Encrypt certificates
- Random passwords are created for n8n, Flowise, Grafana, and Prometheus
- Basic authentication is used for Prometheus access
- Users are created with minimal necessary privileges
- Database security (if enabled):
  - PostgreSQL uses secure passwords for each database
  - Redis is protected with password authentication
  - Data is stored in dedicated volumes

## Troubleshooting

- Check your domain's DNS records to ensure they point to the correct IP address (the setup script now includes automatic DNS validation)
- Verify that ports 80 and 443 are open on your server
- View container logs to detect errors

## Maintenance

### Automatic Backup

The `backup.sh` script creates backups of n8n and Flowise data. You can run it manually or set up a cron job:

```bash
./setup-files/backup.sh
```

This script:
- Stops the containers
- Creates timestamped backup archives
- Restarts the containers
- Removes backups older than 30 days

### Automatic Updates

The `update.sh` script updates the Docker images and restarts containers:

```bash
./setup-files/update.sh
```

This script:
- Creates a backup before updating
- Pulls the latest Docker images
- Restarts the containers
- Verifies services are running correctly

## Monitoring System

### Features

Eсли вы установили систему мониторинга, она включает в себя следующие компоненты:

- **Prometheus** - сервис для сбора и хранения метрик с временными рядами
- **Grafana** - платформа для визуализации и анализа метрик с настраиваемыми дашбордами
- **Node Exporter** - экспортер системных метрик хост-системы
- **cAdvisor** - сборщик метрик контейнеров Docker

### Доступ к мониторингу

- **Grafana**: https://grafana.yourdomain.com (замените yourdomain.com на ваш домен)
- **Prometheus**: https://prometheus.yourdomain.com (доступ по API)

**Учетные данные Grafana** (сохранены в файле passwords.txt):
- **Логин**: admin
- **Пароль**: сгенерированный пароль, указанный в файле passwords.txt

### Собираемые метрики

Система мониторинга собирает данные из следующих источников:

- **Системные метрики**: CPU, память, диск, сеть, загрузка системы
- **Метрики Docker**: использование ресурсов контейнерами, статус, сеть
- **Caddy**: запросы, статус-коды, время ответа, ошибки SSL
- **n8n**: производительность выполнения рабочих процессов, использование ресурсов
- **Flowise**: статус API, использование ресурсов
- **PostgreSQL** (если установлен): соединения, кэш, время выполнения запросов
- **Redis** (если установлен): использование памяти, количество ключей, задержка

### Предустановленные дашборды

В Grafana предустановлены следующие дашборды:

1. **System Overview** - общий обзор состояния системы
2. **Docker Containers** - метрики контейнеров
3. **Caddy Web Server** - метрики веб-сервера и HTTPS
4. **n8n Metrics** - специфичные для n8n метрики
5. **Database Performance** - метрики PostgreSQL и Redis (если установлены)

### Настройка уведомлений

Вы можете настроить уведомления в Grafana для оповещения о критических событиях:

1. Войдите в Grafana по адресу https://grafana.yourdomain.com
2. Перейдите в раздел Alerting (Оповещения)
3. Создайте новое правило оповещения на основе любой метрики
4. Настройте каналы оповещения (email, Telegram, Slack и др.)

### Расширение мониторинга

Для добавления мониторинга дополнительных сервисов:

1. Отредактируйте файл `/opt/monitoring/prometheus.yml`
2. Добавьте новые job_name и target для нового сервиса
3. Перезапустите Prometheus: `docker compose -f /opt/monitoring/docker-compose.yaml restart prometheus`

Для импорта дополнительных дашбордов в Grafana:

1. Найдите ID дашборда на сайте [Grafana Dashboards](https://grafana.com/grafana/dashboards/)
2. В Grafana перейдите в "Dashboards" -> "+ Import"
3. Укажите ID дашборда и настройте источник данных Prometheus

## Database Integration (PostgreSQL and Redis)

### Adminer - Database Management

If you chose to install Adminer during setup, you have access to a powerful web interface for managing your PostgreSQL databases:

- **Access URL**: https://adminer.yourdomain.com (replace yourdomain.com with your actual domain)
- **No additional login required** - Adminer connects directly to your PostgreSQL instance
- **Features**:
  - Table creation and management
  - Data browsing and editing
  - SQL query execution
  - Database structure visualization
  - Import/export functionality
  - User management

#### Using Adminer

1. Open https://adminer.yourdomain.com in your browser
2. Use the following connection details:
   - System: PostgreSQL
   - Server: postgres
   - Username: postgres
   - Password: [the PostgreSQL password from passwords.txt]
   - Database: (leave blank or select a database)
3. Click "Login" to access your database

### PostgreSQL

If you chose to install PostgreSQL during setup, it will be configured to provide:

- Persistent storage for n8n workflows, credentials, and executions
- Database backend for Flowise flows and configurations
- Improved performance and data integrity compared to file-based storage

#### PostgreSQL Details

- **Version**: PostgreSQL 15 (Alpine-based image)
- **Databases**: Separate databases for n8n and Flowise
- **Users**: Dedicated users for each service with limited permissions
- **Data Storage**: Persistent Docker volume (`postgres_data`)
- **Automated Initialization**: The system automatically creates databases and users during first startup

#### Accessing PostgreSQL

To connect to PostgreSQL directly:

```bash
# Connect to PostgreSQL container
docker exec -it postgres psql -U postgres

# List databases
\l

# Connect to n8n database
\c n8n

# Connect to flowise database
\c flowise

# List tables in current database
\dt
```

### Redis

If you chose to install Redis during setup, it provides:

- Queue management for n8n workflow executions (improved performance for heavy workloads)
- Caching for n8n and Flowise (faster response times)
- Reliable task distribution for parallel processing

#### Redis Details

- **Version**: Redis 7 (Alpine-based image)
- **Security**: Password-protected Redis instance
- **Data Storage**: Persistent Docker volume (`redis_data`)
- **Configuration**: Optimized for both caching and queue management
- **Connection Information**:
  - Host: `redis` (inside Docker network)
  - Port: `6379`
  - Password: Stored in your passwords.txt file

### Qdrant - Vector Database

If you chose to install Qdrant during setup, you'll have access to a powerful vector database optimized for similarity search and AI applications:

- **Access URL**: https://qdrant.yourdomain.com (replace yourdomain.com with your actual domain)
- **API Key**: The API key is stored in passwords.txt for secure API access
- **Features**:
  - Vector storage and similarity search
  - High performance vector operations
  - Full-text search capabilities
  - Filtering and metadata support
  - Seamless integration with n8n and Flowise

#### Using Qdrant

1. **With n8n**: Use the Qdrant node in n8n workflows to store and search vectors
   - Configure with the URL: `http://qdrant:6333`
   - Add the API key from your passwords.txt file

2. **With Flowise**: Configure the Qdrant vector store in your AI flows
   - URL: `http://qdrant:6333`
   - API Key: Use the key from passwords.txt

3. **Direct API access**: Send HTTP requests to the Qdrant API at https://qdrant.yourdomain.com
   - Include the API key in the `api-key` header
   - Follow the [Qdrant API documentation](https://qdrant.tech/documentation/concepts/) for available endpoints

#### Accessing Redis

To connect to Redis directly:

```bash
# Get Redis password from .env file
REDIS_PASSWORD=$(grep REDIS_PASSWORD /opt/database/.env | cut -d= -f2)

# Connect to Redis CLI with password
docker exec -it redis redis-cli -a "$REDIS_PASSWORD"

# Check Redis info
info

# Check memory usage
info memory

# Check existing keys
keys *
```

### Performance Considerations

- **Database Size**: Monitor PostgreSQL database size over time
- **Memory Usage**: Redis works best with adequate memory allocation
- **Backup Strategy**: Include PostgreSQL and Redis in your backup routines
- **Scaling**: For high-volume workloads, consider increasing resources for database containers

## License

This project is distributed under the MIT License.

## Author

@codegeek# my_stack

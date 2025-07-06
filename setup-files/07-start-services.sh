#!/bin/bash

echo "Starting services..."

# Create Docker network for all services
echo "Creating Docker network..."
sudo docker network create app-network || true
echo "Docker network created or already exists"

# Create necessary Docker volumes
echo "Creating Docker volumes..."
sudo docker volume create postgres_data || true
sudo docker volume create redis_data || true
sudo docker volume create prometheus_data || true
sudo docker volume create grafana_data || true
sudo docker volume create caddy_monitoring_data || true
sudo docker volume create caddy_monitoring_config || true
echo "Docker volumes created or already exist"

# Check for required files
if [ ! -f "n8n-docker-compose.yaml" ]; then
  echo "ERROR: File n8n-docker-compose.yaml not found"
  exit 1
fi

if [ ! -f "flowise-docker-compose.yaml" ]; then
  echo "ERROR: File flowise-docker-compose.yaml not found"
  exit 1
fi

if [ ! -f ".env" ]; then
  echo "ERROR: File .env not found"
  exit 1
fi

# Проверить необходимость запуска PostgreSQL, Redis, Adminer и Qdrant
INSTALL_POSTGRES=false
INSTALL_REDIS=false
INSTALL_ADMINER=false
INSTALL_QDRANT=false

# Проверяем в .env наличие переменных, говорящих об использовании PostgreSQL и Redis
if grep -q "DB_TYPE=postgresdb" .env; then
  INSTALL_POSTGRES=true
  echo "PostgreSQL configuration detected"
fi

if grep -q "EXECUTIONS_MODE=queue" .env; then
  INSTALL_REDIS=true
  echo "Redis configuration detected"
fi

# Проверяем наличие директории Adminer
if [ -d "/opt/adminer" ]; then
  INSTALL_ADMINER=true
  echo "Adminer configuration detected"
fi

# Проверяем наличие директории Qdrant
if [ -d "/opt/qdrant" ]; then
  INSTALL_QDRANT=true
  echo "Qdrant configuration detected"
fi

# Start database services if configured
if [[ "$INSTALL_POSTGRES" == "true" ]] || [[ "$INSTALL_REDIS" == "true" ]]; then
  if [ -f "/opt/database/docker-compose.yaml" ]; then
    echo "Starting database services..."
    sudo docker compose -f /opt/database/docker-compose.yaml up -d
    if [ $? -ne 0 ]; then
      echo "ERROR: Failed to start database services"
      exit 1
    fi
    echo "Database services started successfully"
    
    # Небольшая пауза для инициализации сервисов БД
    echo "Waiting for database services initialization..."
    sleep 10
  else
    echo "WARNING: Database services were configured but docker-compose file not found"
  fi
fi

# Start Adminer if configured
if [[ "$INSTALL_ADMINER" == "true" ]]; then
  if [ -f "/opt/adminer/docker-compose.yaml" ]; then
    echo "Starting Adminer..."
    sudo docker compose -f /opt/adminer/docker-compose.yaml up -d
    if [ $? -ne 0 ]; then
      echo "ERROR: Failed to start Adminer"
      exit 1
    fi
    echo "Adminer started successfully"
  else
    echo "WARNING: Adminer was configured but docker-compose file not found"
  fi
fi

# Start Qdrant if configured
if [[ "$INSTALL_QDRANT" == "true" ]]; then
  if [ -f "/opt/qdrant/docker-compose.yaml" ]; then
    echo "Starting Qdrant..."
    sudo docker compose -f /opt/qdrant/docker-compose.yaml up -d
    if [ $? -ne 0 ]; then
      echo "ERROR: Failed to start Qdrant"
      exit 1
    fi
    echo "Qdrant started successfully"
  else
    echo "WARNING: Qdrant was configured but docker-compose file not found"
  fi
fi

# Start n8n and Caddy
echo "Starting n8n and Caddy..."
sudo docker compose -f n8n-docker-compose.yaml up -d
if [ $? -ne 0 ]; then
  echo "ERROR: Failed to start n8n and Caddy"
  exit 1
fi

# Wait a bit for the network to be created
echo "Waiting for docker network creation..."
sleep 5

# Check if app-network was created
if ! sudo docker network inspect app-network &> /dev/null; then
  echo "ERROR: Failed to create app-network"
  exit 1
fi

# Start Flowise
echo "Starting Flowise..."
sudo docker compose -f flowise-docker-compose.yaml up -d
if [ $? -ne 0 ]; then
  echo "ERROR: Failed to start Flowise"
  exit 1
fi

# Check that all containers are running
echo "Checking running containers..."
sleep 5

N8N_RUNNING=$(sudo docker ps | grep -c "n8n")
CADDY_RUNNING=$(sudo docker ps | grep -c "caddy")
FLOWISE_RUNNING=$(sudo docker ps | grep -c "flowise")
POSTGRES_RUNNING=0
REDIS_RUNNING=0
ADMINER_RUNNING=0
QDRANT_RUNNING=0

# Проверка запущенных контейнеров БД если они настроены
if [[ "$INSTALL_POSTGRES" == "true" ]]; then
  POSTGRES_RUNNING=$(sudo docker ps | grep -c "postgres")
fi

if [[ "$INSTALL_REDIS" == "true" ]]; then
  REDIS_RUNNING=$(sudo docker ps | grep -c "redis")
fi

if [[ "$INSTALL_ADMINER" == "true" ]]; then
  ADMINER_RUNNING=$(sudo docker ps | grep -c "adminer")
fi

if [[ "$INSTALL_QDRANT" == "true" ]]; then
  QDRANT_RUNNING=$(sudo docker ps | grep -c "qdrant")
fi

# Формирование статуса запущенных контейнеров
ALL_RUNNING=true
STATUS_MESSAGE="✅ The following containers are running successfully:\n"
STATUS_MESSAGE+="  n8n: $([ $N8N_RUNNING -eq 1 ] && echo "✓" || { ALL_RUNNING=false; echo "✗"; })\n"
STATUS_MESSAGE+="  Caddy: $([ $CADDY_RUNNING -eq 1 ] && echo "✓" || { ALL_RUNNING=false; echo "✗"; })\n"
STATUS_MESSAGE+="  Flowise: $([ $FLOWISE_RUNNING -eq 1 ] && echo "✓" || { ALL_RUNNING=false; echo "✗"; })\n"

# Добавляем информацию о PostgreSQL и Redis если они настроены
if [[ "$INSTALL_POSTGRES" == "true" ]]; then
  STATUS_MESSAGE+="  PostgreSQL: $([ $POSTGRES_RUNNING -eq 1 ] && echo "✓" || { ALL_RUNNING=false; echo "✗"; })\n"
fi

if [[ "$INSTALL_REDIS" == "true" ]]; then
  STATUS_MESSAGE+="  Redis: $([ $REDIS_RUNNING -eq 1 ] && echo "✓" || { ALL_RUNNING=false; echo "✗"; })\n"
fi

if [[ "$INSTALL_ADMINER" == "true" ]]; then
  STATUS_MESSAGE+="  Adminer: $([ $ADMINER_RUNNING -eq 1 ] && echo "✓" || { ALL_RUNNING=false; echo "✗"; })\n"
fi

if [[ "$INSTALL_QDRANT" == "true" ]]; then
  STATUS_MESSAGE+="  Qdrant: $([ $QDRANT_RUNNING -eq 1 ] && echo "✓" || { ALL_RUNNING=false; echo "✗"; })\n"
fi

# Вывод итогового статуса
if [ "$ALL_RUNNING" = true ]; then
  echo -e "✅ All containers are running successfully"
else
  echo -e "ERROR: Not all containers are running\n$STATUS_MESSAGE"
  exit 1
fi
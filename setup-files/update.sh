#!/bin/bash

# Скрипт автоматического обновления образов и перезапуска контейнеров
# Рекомендуется добавить в crontab для регулярного выполнения:
# 0 3 * * 0 /opt/cloud-local-n8n-flowise/setup-files/update.sh

# Цвета для вывода сообщений
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Пути к файлам docker-compose
N8N_COMPOSE_FILE="/opt/n8n/n8n-docker-compose.yaml"
FLOWISE_COMPOSE_FILE="/opt/flowise/flowise-docker-compose.yaml"

# Функция для вывода сообщений
log_message() {
  local type=$1
  local message=$2
  local color=$NC
  
  if [ "$type" == "info" ]; then
    color=$GREEN
  elif [ "$type" == "warning" ]; then
    color=$YELLOW
  elif [ "$type" == "error" ]; then
    color=$RED
  fi
  
  echo -e "${color}[$(date '+%Y-%m-%d %H:%M:%S')] $message${NC}"
}

# Функция для проверки статуса контейнеров
check_containers() {
  local service=$1
  local status=$(docker ps --filter "name=$service" --format "{{.Status}}" | grep "Up")
  
  if [ -z "$status" ]; then
    return 1 # Контейнер не запущен
  else
    return 0 # Контейнер запущен
  fi
}

# Проверка наличия необходимых файлов
if [ ! -f "$N8N_COMPOSE_FILE" ]; then
  log_message "error" "Файл $N8N_COMPOSE_FILE не найден"
  exit 1
fi

if [ ! -f "$FLOWISE_COMPOSE_FILE" ]; then
  log_message "error" "Файл $FLOWISE_COMPOSE_FILE не найден"
  exit 1
fi

# Создание резервной копии перед обновлением
log_message "info" "Создание резервной копии перед обновлением..."
if [ -f "/opt/cloud-local-n8n-flowise/setup-files/backup.sh" ]; then
  /opt/cloud-local-n8n-flowise/setup-files/backup.sh
  if [ $? -ne 0 ]; then
    log_message "warning" "Не удалось создать резервную копию перед обновлением"
    read -p "Продолжить обновление без резервной копии? (y/n): " CONTINUE
    if [[ ! "$CONTINUE" =~ ^[Yy]$ ]]; then
      log_message "info" "Обновление прервано пользователем"
      exit 1
    fi
  fi
else
  log_message "warning" "Скрипт резервного копирования не найден, продолжение без резервной копии"
fi

log_message "info" "Начало процесса обновления..."

# Обновление образов n8n
log_message "info" "Обновление образов n8n..."
cd $(dirname "$N8N_COMPOSE_FILE")
docker compose pull
if [ $? -ne 0 ]; then
  log_message "error" "Не удалось обновить образы n8n"
  exit 1
fi

# Перезапуск контейнеров n8n
log_message "info" "Перезапуск контейнеров n8n..."
docker compose up -d
if [ $? -ne 0 ]; then
  log_message "error" "Не удалось перезапустить контейнеры n8n"
  exit 1
fi

# Проверка статуса контейнеров n8n
sleep 10 # Ждем некоторое время для запуска контейнеров
if ! check_containers "n8n"; then
  log_message "error" "Контейнер n8n не запустился после обновления"
  exit 1
fi

# Обновление образов Flowise
log_message "info" "Обновление образов Flowise..."
cd $(dirname "$FLOWISE_COMPOSE_FILE")
docker compose pull
if [ $? -ne 0 ]; then
  log_message "error" "Не удалось обновить образы Flowise"
  exit 1
fi

# Перезапуск контейнеров Flowise
log_message "info" "Перезапуск контейнеров Flowise..."
docker compose up -d
if [ $? -ne 0 ]; then
  log_message "error" "Не удалось перезапустить контейнеры Flowise"
  exit 1
fi

# Проверка статуса контейнеров Flowise
sleep 10 # Ждем некоторое время для запуска контейнеров
if ! check_containers "flowise"; then
  log_message "error" "Контейнер Flowise не запустился после обновления"
  exit 1
fi

# Проверка наличия обновлений системы и Docker
log_message "info" "Проверка наличия обновлений системы..."
if command -v apt-get &> /dev/null; then
  apt-get update -qq
  UPDATES=$(apt-get -s upgrade | grep -c "upgraded,")
  if [ "$UPDATES" -gt 0 ]; then
    log_message "warning" "Доступны обновления системы: $UPDATES пакетов. Рекомендуется обновить систему."
  fi
fi

# Очистка неиспользуемых образов Docker
log_message "info" "Очистка неиспользуемых образов Docker..."
docker image prune -af --filter "until=168h"

log_message "info" "Обновление завершено: $(date)"
log_message "info" "Проверка статуса контейнеров:"
docker ps | grep -E 'n8n|flowise|caddy'

exit 0

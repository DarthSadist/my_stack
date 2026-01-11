#!/bin/bash

# Скрипт автоматического резервного копирования данных n8n и Flowise
# Рекомендуется добавить в crontab для регулярного выполнения:
# 0 2 * * * /opt/cloud-local-n8n-flowise/setup-files/backup.sh

# Цвета для вывода сообщений
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Настройки
BACKUP_DIR="/opt/backups"
DATE=$(date +%Y-%m-%d)
BACKUP_FILE="n8n-flowise-backup-$DATE.tar.gz"
RETENTION_DAYS=30

# List of Docker volumes to backup
VOLUMES="n8n_data postgres_data redis_data grafana_data prometheus_data qdrant_data caddy_data caddy_config"

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

# Проверка наличия директории для резервных копий
if [ ! -d "$BACKUP_DIR" ]; then
  log_message "info" "Создание директории для резервных копий: $BACKUP_DIR"
  mkdir -p $BACKUP_DIR
  if [ $? -ne 0 ]; then
    log_message "error" "Не удалось создать директорию для резервных копий"
    exit 1
  fi
fi

# Проверка наличия необходимых директорий для бэкапа
if [ ! -d "/opt/n8n" ] || [ ! -d "/opt/flowise" ]; then
  log_message "error" "Директории /opt/n8n или /opt/flowise не существуют"
  exit 1
fi

log_message "info" "Начало создания резервной копии..."

# Остановка контейнеров для согласованного бэкапа
log_message "info" "Остановка контейнеров..."
docker compose -f /opt/n8n/n8n-docker-compose.yaml stop
if [ $? -ne 0 ]; then
  log_message "warning" "Не удалось остановить контейнеры n8n"
  # Продолжаем работу, возможно будет неполный бэкап
fi

docker compose -f /opt/flowise/flowise-docker-compose.yaml stop
if [ $? -ne 0 ]; then
  log_message "warning" "Не удалось остановить контейнеры Flowise"
  # Продолжаем работу, возможно будет неполный бэкап
fi

# Архивирование данных
log_message "info" "Архивирование данных..."
tar -czf $BACKUP_DIR/$BACKUP_FILE /opt/n8n /opt/flowise
if [ $? -ne 0 ]; then
  log_message "error" "Ошибка при архивировании данных"
  # Запускаем контейнеры перед выходом
  docker compose -f /opt/n8n/n8n-docker-compose.yaml start
  docker compose -f /opt/flowise/flowise-docker-compose.yaml start
  exit 1
fi

# Backup Docker volumes
log_message "info" "Резервное копирование Docker volumes..."
VOLUME_BACKUP_FILE="volumes-backup-$DATE.tar.gz"
VOLUME_BACKUP_PATH="$BACKUP_DIR/$VOLUME_BACKUP_FILE"

# Create temporary directory for volume backups
TEMP_DIR=$(mktemp -d)
if [ $? -ne 0 ]; then
  log_message "error" "Не удалось создать временную директорию"
  exit 1
fi

# Backup each volume if it exists
for vol in $VOLUMES; do
  if docker volume inspect "$vol" &>/dev/null; then
    log_message "info" "Копирование volume $vol..."
    docker run --rm -v "$vol":/data -v "$TEMP_DIR":/backup alpine tar -czf "/backup/$vol.tar.gz" -C /data .
    if [ $? -ne 0 ]; then
      log_message "warning" "Не удалось создать бэкап volume $vol"
    fi
  else
    log_message "warning" "Volume $vol не существует, пропускается"
  fi
done

# Create final volume backup archive
tar -czf "$VOLUME_BACKUP_PATH" -C "$TEMP_DIR" .
if [ $? -ne 0 ]; then
  log_message "error" "Ошибка при создании архива volumes"
  rm -rf "$TEMP_DIR"
  exit 1
fi

# Cleanup temporary directory
rm -rf "$TEMP_DIR"

# Перезапуск контейнеров
log_message "info" "Перезапуск контейнеров..."
docker compose -f /opt/n8n/n8n-docker-compose.yaml start
docker compose -f /opt/flowise/flowise-docker-compose.yaml start

# Проверка размера созданного бэкапа
BACKUP_SIZE=$(du -h $BACKUP_DIR/$BACKUP_FILE | cut -f1)
VOLUME_BACKUP_SIZE=$(du -h "$VOLUME_BACKUP_PATH" 2>/dev/null | cut -f1 || echo "N/A")

# Удаление старых резервных копий (старше указанного количества дней)
log_message "info" "Удаление старых резервных копий (старше $RETENTION_DAYS дней)..."
find $BACKUP_DIR -name "n8n-flowise-backup-*.tar.gz" -type f -mtime +$RETENTION_DAYS -delete
find $BACKUP_DIR -name "volumes-backup-*.tar.gz" -type f -mtime +$RETENTION_DAYS -delete
DELETED_COUNT=$?

log_message "info" "Резервное копирование завершено успешно!"
log_message "info" "Файл: $BACKUP_DIR/$BACKUP_FILE"
log_message "info" "Размер: $BACKUP_SIZE"
log_message "info" "Volumes backup: $VOLUME_BACKUP_PATH"
log_message "info" "Volumes backup size: $VOLUME_BACKUP_SIZE"
log_message "info" "Удалено устаревших резервных копий: $DELETED_COUNT"

exit 0

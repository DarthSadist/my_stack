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

# Перезапуск контейнеров
log_message "info" "Перезапуск контейнеров..."
docker compose -f /opt/n8n/n8n-docker-compose.yaml start
docker compose -f /opt/flowise/flowise-docker-compose.yaml start

# Проверка размера созданного бэкапа
BACKUP_SIZE=$(du -h $BACKUP_DIR/$BACKUP_FILE | cut -f1)

# Удаление старых резервных копий (старше указанного количества дней)
log_message "info" "Удаление старых резервных копий (старше $RETENTION_DAYS дней)..."
find $BACKUP_DIR -name "n8n-flowise-backup-*.tar.gz" -type f -mtime +$RETENTION_DAYS -delete
DELETED_COUNT=$?

log_message "info" "Резервное копирование завершено успешно!"
log_message "info" "Файл: $BACKUP_DIR/$BACKUP_FILE"
log_message "info" "Размер: $BACKUP_SIZE"
log_message "info" "Удалено устаревших резервных копий: $DELETED_COUNT"

exit 0

#!/bin/bash

# Get variables from the main script via arguments
USER_EMAIL=$1
DOMAIN_NAME=$2
GENERIC_TIMEZONE=$3
INSTALL_MONITORING=$4
INSTALL_POSTGRES=$5
INSTALL_REDIS=$6
INSTALL_ADMINER=$7
INSTALL_QDRANT=$8

if [ -z "$USER_EMAIL" ] || [ -z "$DOMAIN_NAME" ]; then
  echo "ERROR: Email or domain name not specified"
  echo "Usage: $0 user@example.com example.com [timezone] [install_monitoring] [install_postgres] [install_redis] [install_adminer] [install_qdrant]"
  exit 1
fi

if [ -z "$GENERIC_TIMEZONE" ]; then
  GENERIC_TIMEZONE="UTC"
fi

# Set default values if not provided
INSTALL_MONITORING=${INSTALL_MONITORING:-false}
INSTALL_POSTGRES=${INSTALL_POSTGRES:-false}
INSTALL_REDIS=${INSTALL_REDIS:-false}
INSTALL_ADMINER=${INSTALL_ADMINER:-false}
INSTALL_QDRANT=${INSTALL_QDRANT:-false}

# Определение пути к файлу с паролями
PASSWORD_FILE="./setup-files/passwords.txt"

# Проверка существования директории для файла с паролями
mkdir -p "$(dirname "$PASSWORD_FILE")"

# Создание или очистка файла с паролями
echo "# Сгенерированные пароли и ключи доступа" > "$PASSWORD_FILE"

echo "Generating secret keys and passwords..."

# Function to generate random strings
generate_random_string() {
  length=$1
  cat /dev/urandom | tr -dc 'a-zA-Z0-9!@#$%^&*()-_=+' | fold -w ${length} | head -n 1
}

# Function to generate safe passwords (no special bash characters)
generate_safe_password() {
  length=$1
  cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w ${length} | head -n 1
}

# Generating keys and passwords
N8N_ENCRYPTION_KEY=$(generate_random_string 40)
if [ -z "$N8N_ENCRYPTION_KEY" ]; then
  echo "ERROR: Failed to generate encryption key for n8n"
  exit 1
fi

N8N_USER_MANAGEMENT_JWT_SECRET=$(generate_random_string 40)
if [ -z "$N8N_USER_MANAGEMENT_JWT_SECRET" ]; then
  echo "ERROR: Failed to generate JWT secret for n8n"
  exit 1
fi

# Use safer password generation function (alphanumeric only)
N8N_PASSWORD=$(generate_safe_password 16)
if [ -z "$N8N_PASSWORD" ]; then
  echo "ERROR: Failed to generate password for n8n"
  exit 1
fi

FLOWISE_PASSWORD=$(generate_safe_password 16)
if [ -z "$FLOWISE_PASSWORD" ]; then
  echo "ERROR: Failed to generate password for Flowise"
  exit 1
fi

# Generate monitoring passwords if monitoring is enabled
GRAFANA_PASSWORD=""
PROMETHEUS_USER=""
PROMETHEUS_PASSWORD=""
PROMETHEUS_HASHED_PASSWORD=""

# Generate database passwords if PostgreSQL is enabled
POSTGRES_PASSWORD=""
POSTGRES_N8N_PASSWORD=""
POSTGRES_FLOWISE_PASSWORD=""

# Generate Redis password if Redis is enabled
REDIS_PASSWORD=""

# Generate PostgreSQL passwords if enabled
if [[ "$INSTALL_POSTGRES" == "true" ]]; then
  # Generate main Postgres admin password
  POSTGRES_PASSWORD=$(generate_safe_password 16)
  if [ -z "$POSTGRES_PASSWORD" ]; then
    echo "ERROR: Failed to generate password for PostgreSQL"
    exit 1
  fi
  
  # Generate n8n database password
  POSTGRES_N8N_PASSWORD=$(generate_safe_password 16)
  if [ -z "$POSTGRES_N8N_PASSWORD" ]; then
    echo "ERROR: Failed to generate n8n database password"
    exit 1
  fi
  
  # Generate Flowise database password
  POSTGRES_FLOWISE_PASSWORD=$(generate_safe_password 16)
  if [ -z "$POSTGRES_FLOWISE_PASSWORD" ]; then
    echo "ERROR: Failed to generate Flowise database password"
    exit 1
  fi
  
  echo "Generated PostgreSQL credentials successfully."
  
  # Create postgres.env file
  cat > postgres.env << EOL
# Settings for PostgreSQL
POSTGRES_PASSWORD=$POSTGRES_PASSWORD
POSTGRES_N8N_PASSWORD=$POSTGRES_N8N_PASSWORD
POSTGRES_FLOWISE_PASSWORD=$POSTGRES_FLOWISE_PASSWORD
EOL

  if [ $? -ne 0 ]; then
    echo "ERROR: Failed to create postgres.env file"
    exit 1
  fi
  
  # Create PostgreSQL directory
  sudo mkdir -p /opt/postgres
  sudo cp postgres.env /opt/postgres/.env
  
  echo "PostgreSQL credentials generated and saved to postgres.env"
  echo "Password for PostgreSQL: $POSTGRES_PASSWORD"
  echo "Password for n8n database: $POSTGRES_N8N_PASSWORD"
  echo "Password for Flowise database: $POSTGRES_FLOWISE_PASSWORD"
fi

# Generate Redis password if enabled
if [[ "$INSTALL_REDIS" == "true" ]]; then
  # Generate Redis password
  REDIS_PASSWORD=$(generate_safe_password 16)
  if [ -z "$REDIS_PASSWORD" ]; then
    echo "ERROR: Failed to generate password for Redis"
    exit 1
  fi
  
  echo "Generated Redis credentials successfully."
  
  # Create redis.env file
  cat > redis.env << EOL
# Settings for Redis
REDIS_PASSWORD=$REDIS_PASSWORD
EOL

  if [ $? -ne 0 ]; then
    echo "ERROR: Failed to create redis.env file"
    exit 1
  fi
  
  # Create Redis directory
  sudo mkdir -p /opt/redis
  sudo cp redis.env /opt/redis/.env
  
  echo "Redis credentials generated and saved to redis.env"
  echo "Password for Redis: $REDIS_PASSWORD"
fi

# Generate monitoring passwords if monitoring is enabled
if [[ "$INSTALL_MONITORING" == "true" ]]; then
  # Generate Grafana admin password
  GRAFANA_PASSWORD=$(generate_safe_password 16)
  if [ -z "$GRAFANA_PASSWORD" ]; then
    echo "ERROR: Failed to generate password for Grafana"
    exit 1
  fi
  
  # Generate Prometheus user and password
  PROMETHEUS_USER="prometheus_admin"
  PROMETHEUS_PASSWORD=$(generate_safe_password 16)
  if [ -z "$PROMETHEUS_PASSWORD" ]; then
    echo "ERROR: Failed to generate password for Prometheus"
    exit 1
  fi
  
  # Hash the Prometheus password for Caddy basic auth
  # We'll use the bcrypt hash format that Caddy requires
  PROMETHEUS_HASHED_PASSWORD=$(echo "$PROMETHEUS_PASSWORD" | caddy hash-password)
  if [ -z "$PROMETHEUS_HASHED_PASSWORD" ]; then
    echo "WARN: Failed to hash Prometheus password with Caddy. Checking if Docker+Caddy is available."
    # Try using Docker if caddy command is not available
    PROMETHEUS_HASHED_PASSWORD=$(docker run --rm caddy caddy hash-password --plaintext "$PROMETHEUS_PASSWORD" 2>/dev/null)
    
    if [ -z "$PROMETHEUS_HASHED_PASSWORD" ]; then
      echo "WARN: Could not generate bcrypt hash for Prometheus password."
      echo "You will need to manually update Caddyfile-monitoring with a hashed password later."
      # Use a placeholder
      PROMETHEUS_HASHED_PASSWORD="JDJhJDE0JEZrOHQuUXVBaEMvckxwOVVMcEZOZk9DNEVaQWJjNmgvcWxuVDlUV2NTd0hxMWRvTUZGT0N1"
    fi
  fi
  
  echo "Generated monitoring credentials successfully."
  
  # Create monitoring.env file
  cat > monitoring.env << EOL
# Settings for Grafana
GRAFANA_PASSWORD=$GRAFANA_PASSWORD

# Settings for Prometheus
PROMETHEUS_USER=$PROMETHEUS_USER
PROMETHEUS_PASSWORD=$PROMETHEUS_PASSWORD
PROMETHEUS_HASHED_PASSWORD=$PROMETHEUS_HASHED_PASSWORD

# Domain settings
DOMAIN_NAME=$DOMAIN_NAME
EOL

  if [ $? -ne 0 ]; then
    echo "ERROR: Failed to create monitoring.env file"
    exit 1
  fi
  
  # Create monitoring directories
  sudo mkdir -p /opt/monitoring
  sudo cp monitoring.env /opt/monitoring/.env
  
  echo "Monitoring credentials generated and saved to monitoring.env"
  echo "Password for Grafana: $GRAFANA_PASSWORD"
  echo "Password for Prometheus: $PROMETHEUS_PASSWORD"
fi

# Writing values to .env file
cat > .env << EOL
# Settings for n8n
N8N_ENCRYPTION_KEY=$N8N_ENCRYPTION_KEY
N8N_USER_MANAGEMENT_JWT_SECRET=$N8N_USER_MANAGEMENT_JWT_SECRET
N8N_DEFAULT_USER_EMAIL=$USER_EMAIL
N8N_DEFAULT_USER_PASSWORD=$N8N_PASSWORD

# n8n host configuration
SUBDOMAIN=n8n
GENERIC_TIMEZONE=$GENERIC_TIMEZONE

# Settings for Flowise
FLOWISE_USERNAME=admin
FLOWISE_PASSWORD=$FLOWISE_PASSWORD

# Domain settings
DOMAIN_NAME=$DOMAIN_NAME

# Adminer settings (if enabled)
if [[ "$INSTALL_ADMINER" == "true" ]]; then
  SUBDOMAIN_ADMINER="adminer"
  ADMINER_UPSTREAM="adminer:8080"
  
  # Add Adminer settings to passwords.txt
  cat >> "$PASSWORD_FILE" << EOL

# Adminer Settings
Adminer URL: https://${SUBDOMAIN_ADMINER}.${DOMAIN_NAME}
Database Host: postgres
Database Port: 5432

Powerful web interface for managing your PostgreSQL database.
EOL
  
  # Create Adminer .env file
  mkdir -p /opt/adminer
  cat > /opt/adminer/.env << EOL
# Adminer settings
SUBDOMAIN_ADMINER=${SUBDOMAIN_ADMINER}
DOMAIN_NAME=${DOMAIN_NAME}
ADMINER_UPSTREAM=${ADMINER_UPSTREAM}
EOL

# Qdrant settings (if enabled)
if [[ "$INSTALL_QDRANT" == "true" ]]; then
  SUBDOMAIN_QDRANT="qdrant"
  QDRANT_UPSTREAM="qdrant:6333"
  QDRANT_API_KEY=$(generate_safe_password 32)
  
  # Add Qdrant settings to passwords.txt
  cat >> "$PASSWORD_FILE" << EOL

# Qdrant Settings
Qdrant URL: https://${SUBDOMAIN_QDRANT}.${DOMAIN_NAME}
Qdrant API Key: ${QDRANT_API_KEY}

Vector database for similarity search and AI applications.
EOL
  
  # Create Qdrant .env file
  mkdir -p /opt/qdrant
  cat > /opt/qdrant/.env << EOL
# Qdrant settings
SUBDOMAIN_QDRANT=${SUBDOMAIN_QDRANT}
DOMAIN_NAME=${DOMAIN_NAME}
QDRANT_UPSTREAM=${QDRANT_UPSTREAM}
QDRANT_API_KEY=${QDRANT_API_KEY}
QDRANT_DATA_DIR=qdrant_data
EOL

  # Add Qdrant settings to main .env for integration with n8n and Flowise
  cat >> .env << QDRANT_EOF

# Qdrant vector database settings
QDRANT_URL=http://qdrant:6333
QDRANT_API_KEY=${QDRANT_API_KEY}
QDRANT_EOF
fi

# PostgreSQL settings (if enabled)
if [[ "$INSTALL_POSTGRES" == "true" ]]; then
  cat >> .env << POSTGRES_EOF

# PostgreSQL settings for n8n
DB_TYPE=postgresdb
DB_POSTGRESDB_HOST=postgres
DB_POSTGRESDB_PORT=5432
DB_POSTGRESDB_DATABASE=n8n
DB_POSTGRESDB_USER=n8n
DB_POSTGRESDB_PASSWORD=$POSTGRES_N8N_PASSWORD

# PostgreSQL settings for Flowise
FLOWISE_DATABASE_TYPE=postgres
FLOWISE_DATABASE_HOST=postgres
FLOWISE_DATABASE_PORT=5432
FLOWISE_DATABASE_NAME=flowise
FLOWISE_DATABASE_USER=flowise
FLOWISE_DATABASE_PASSWORD=$POSTGRES_FLOWISE_PASSWORD
POSTGRES_EOF
fi

# Redis settings (if enabled)
if [[ "$INSTALL_REDIS" == "true" ]]; then
  cat >> .env << REDIS_EOF

# Redis settings for n8n
EXECUTIONS_MODE=queue
QUEUE_BULL_REDIS_HOST=redis
QUEUE_BULL_REDIS_PORT=6379
QUEUE_BULL_REDIS_PASSWORD=$REDIS_PASSWORD
CACHE_ENABLED=true
CACHE_REDIS_HOST=redis
CACHE_REDIS_PORT=6379
CACHE_REDIS_PASSWORD=$REDIS_PASSWORD

# Redis settings for Flowise
FLOWISE_REDIS_ENABLED=true
FLOWISE_REDIS_HOST=redis
FLOWISE_REDIS_PORT=6379
FLOWISE_REDIS_PASSWORD=$REDIS_PASSWORD
REDIS_EOF
fi

if [ $? -ne 0 ]; then
  echo "ERROR: Failed to create .env file"
  exit 1
fi

echo "Secret keys generated and saved to .env file"
echo "Password for n8n: $N8N_PASSWORD"
echo "Password for Flowise: $FLOWISE_PASSWORD"

# Save passwords for future use - using quotes to properly handle special characters
echo "N8N_PASSWORD=\"$N8N_PASSWORD\"" > ./setup-files/passwords.txt
echo "FLOWISE_PASSWORD=\"$FLOWISE_PASSWORD\"" >> ./setup-files/passwords.txt

# Add monitoring passwords if monitoring is enabled
if [[ "$INSTALL_MONITORING" == "true" ]]; then
  echo "GRAFANA_PASSWORD=\"$GRAFANA_PASSWORD\"" >> ./setup-files/passwords.txt
  echo "PROMETHEUS_USER=\"$PROMETHEUS_USER\"" >> ./setup-files/passwords.txt
  echo "PROMETHEUS_PASSWORD=\"$PROMETHEUS_PASSWORD\"" >> ./setup-files/passwords.txt
  # Don't include hashed password in the passwords.txt file
fi

# Add PostgreSQL passwords if PostgreSQL is enabled
if [[ "$INSTALL_POSTGRES" == "true" ]]; then
  echo "POSTGRES_PASSWORD=\"$POSTGRES_PASSWORD\"" >> ./setup-files/passwords.txt
  echo "POSTGRES_N8N_PASSWORD=\"$POSTGRES_N8N_PASSWORD\"" >> ./setup-files/passwords.txt
  echo "POSTGRES_FLOWISE_PASSWORD=\"$POSTGRES_FLOWISE_PASSWORD\"" >> ./setup-files/passwords.txt
fi

# Add Redis password if Redis is enabled
if [[ "$INSTALL_REDIS" == "true" ]]; then
  echo "REDIS_PASSWORD=\"$REDIS_PASSWORD\"" >> ./setup-files/passwords.txt
fi

echo "✅ Secret keys and passwords successfully generated"
exit 0 
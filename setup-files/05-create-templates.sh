#!/bin/bash

# Get variables from the main script via arguments
DOMAIN_NAME=$1
INSTALL_MONITORING=$2
INSTALL_POSTGRES=$3
INSTALL_REDIS=$4
INSTALL_ADMINER=$5
INSTALL_QDRANT=$6

if [ -z "$DOMAIN_NAME" ]; then
  echo "ERROR: Domain name not specified"
  echo "Usage: $0 example.com [install_monitoring] [install_postgres] [install_redis] [install_adminer] [install_qdrant]"
  exit 1
fi

# Set default values if not provided
INSTALL_MONITORING=${INSTALL_MONITORING:-false}
INSTALL_POSTGRES=${INSTALL_POSTGRES:-false}
INSTALL_REDIS=${INSTALL_REDIS:-false}
INSTALL_ADMINER=${INSTALL_ADMINER:-false}
INSTALL_QDRANT=${INSTALL_QDRANT:-false}

echo "Creating templates and configuration files..."

# Check for template files and create them
if [ ! -f "n8n-docker-compose.yaml.template" ]; then
  echo "Creating template n8n-docker-compose.yaml.template..."
  cat > n8n-docker-compose.yaml.template << EOL
version: '3'

volumes:
  n8n_data:
    external: true
  caddy_data:
    external: true
  caddy_config:

services:
  n8n:
    image: n8nio/n8n:latest
    container_name: n8n
    restart: unless-stopped
    environment:
      - N8N_ENCRYPTION_KEY=\${N8N_ENCRYPTION_KEY}
      - N8N_USER_MANAGEMENT_DISABLED=false
      - N8N_DIAGNOSTICS_ENABLED=false
      - N8N_PERSONALIZATION_ENABLED=false
      - N8N_USER_MANAGEMENT_JWT_SECRET=\${N8N_USER_MANAGEMENT_JWT_SECRET}
      - N8N_DEFAULT_USER_EMAIL=\${N8N_DEFAULT_USER_EMAIL}
      - N8N_DEFAULT_USER_PASSWORD=\${N8N_DEFAULT_USER_PASSWORD}
      - N8N_COMMUNITY_PACKAGES_ALLOW_TOOL_USAGE=true
    volumes:
      - n8n_data:/home/node/.n8n
      - /opt/n8n/files:/files
    networks:
      - app-network

  caddy:
    image: caddy:2
    container_name: caddy
    restart: unless-stopped
    ports:
      - 80:80
      - 443:443
    volumes:
      - /opt/n8n/Caddyfile:/etc/caddy/Caddyfile
      - caddy_data:/data
      - caddy_config:/config
    networks:
      - app-network

networks:
  app-network:
    name: app-network
    driver: bridge
EOL
  if [ $? -ne 0 ]; then
    echo "ERROR: Failed to create file n8n-docker-compose.yaml.template"
    exit 1
  fi
else
  echo "Template n8n-docker-compose.yaml.template already exists"
fi

if [ ! -f "flowise-docker-compose.yaml.template" ]; then
  echo "Creating template flowise-docker-compose.yaml.template..."
  cat > flowise-docker-compose.yaml.template << EOL
version: '3'

services:
  flowise:
    image: flowiseai/flowise
    restart: unless-stopped
    container_name: flowise
    environment:
      - PORT=3001
      - FLOWISE_USERNAME=\${FLOWISE_USERNAME}
      - FLOWISE_PASSWORD=\${FLOWISE_PASSWORD}
    volumes:
      - /opt/flowise:/root/.flowise
    networks:
      - app-network

networks:
  app-network:
    external: true
EOL
  if [ $? -ne 0 ]; then
    echo "ERROR: Failed to create file flowise-docker-compose.yaml.template"
    exit 1
  fi
else
  echo "Template flowise-docker-compose.yaml.template already exists"
fi

if [ ! -f "database-docker-compose.yaml.template" ]; then
  echo "Creating template database-docker-compose.yaml.template..."
  cat > database-docker-compose.yaml.template << EOL
version: '3'

services:
  postgres:
    image: postgres:latest
    container_name: postgres
    restart: unless-stopped
    environment:
      - POSTGRES_USER=\${POSTGRES_USER}
      - POSTGRES_PASSWORD=\${POSTGRES_PASSWORD}
      - POSTGRES_DB=\${POSTGRES_DB}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    networks:
      - app-network

  redis:
    image: redis:latest
    container_name: redis
    restart: unless-stopped
    environment:
      - REDIS_PASSWORD=\${REDIS_PASSWORD}
    volumes:
      - redis_data:/data
    networks:
      - app-network

volumes:
  postgres_data:
    external: true
  redis_data:
    external: true

networks:
  app-network:
    external: true
EOL
  if [ $? -ne 0 ]; then
    echo "ERROR: Failed to create file database-docker-compose.yaml.template"
    exit 1
  fi
else
  echo "Template database-docker-compose.yaml.template already exists"
fi

if [ ! -f "adminer-docker-compose.yaml.template" ]; then
  echo "Creating template adminer-docker-compose.yaml.template..."
  cat > adminer-docker-compose.yaml.template << EOL
version: '3'

services:
  adminer:
    image: adminer:latest
    container_name: adminer
    restart: unless-stopped
    environment:
      - ADMINER_DESIGN=pepa-linha
    ports:
      - 8080:8080
    networks:
      - app-network

networks:
  app-network:
    external: true
EOL
  if [ $? -ne 0 ]; then
    echo "ERROR: Failed to create file adminer-docker-compose.yaml.template"
    exit 1
  fi
else
  echo "Template adminer-docker-compose.yaml.template already exists"
fi

if [ ! -f "adminer-Caddyfile.template" ]; then
  echo "Creating template adminer-Caddyfile.template..."
  cat > adminer-Caddyfile.template << EOL
adminer.${DOMAIN_NAME} {
  reverse_proxy adminer:8080
}
EOL
  if [ $? -ne 0 ]; then
    echo "ERROR: Failed to create file adminer-Caddyfile.template"
    exit 1
  fi
else
  echo "Template adminer-Caddyfile.template already exists"
fi

# Copy templates to working files
cp n8n-docker-compose.yaml.template n8n-docker-compose.yaml
if [ $? -ne 0 ]; then
  echo "ERROR: Failed to copy n8n-docker-compose.yaml.template to working file"
  exit 1
fi

cp flowise-docker-compose.yaml.template flowise-docker-compose.yaml
if [ $? -ne 0 ]; then
  echo "ERROR: Failed to copy flowise-docker-compose.yaml.template to working file"
  exit 1
fi

# Setup database services if enabled
if [[ "$INSTALL_POSTGRES" == "true" ]] || [[ "$INSTALL_REDIS" == "true" ]]; then
  echo "Setting up database services..."
  
  # Create database directory
  sudo mkdir -p /opt/database
  if [ $? -ne 0 ]; then
    echo "ERROR: Failed to create database directory"
    exit 1
  fi
  
  # Create database-docker-compose.yaml
  sudo cp database-docker-compose.yaml.template /opt/database/docker-compose.yaml
  if [ $? -ne 0 ]; then
    echo "ERROR: Failed to copy database-docker-compose.yaml.template to working file"
    exit 1
  fi
  
  # Setup Adminer if enabled
  if [[ "$INSTALL_ADMINER" == "true" ]]; then
    echo "Setting up Adminer..."
    
    # Create adminer directory
    sudo mkdir -p /opt/adminer
    if [ $? -ne 0 ]; then
      echo "ERROR: Failed to create adminer directory"
      exit 1
    fi
    
    # Copy adminer-docker-compose.yaml template to working file
    sudo cp adminer-docker-compose.yaml.template /opt/adminer/docker-compose.yaml
    if [ $? -ne 0 ]; then
      echo "ERROR: Failed to copy adminer-docker-compose.yaml.template to working file"
      exit 1
    fi
    
    # Copy Caddyfile for adminer
    sudo cp adminer-Caddyfile.template /opt/adminer/Caddyfile
    if [ $? -ne 0 ]; then
      echo "ERROR: Failed to copy adminer-Caddyfile.template to /opt/adminer/"
      exit 1
    fi
    
    echo "✅ Adminer setup completed"
  fi
  
  # Setup Qdrant if enabled
  if [[ "$INSTALL_QDRANT" == "true" ]]; then
    echo "Setting up Qdrant..."
    
    # Create qdrant directory
    sudo mkdir -p /opt/qdrant
    if [ $? -ne 0 ]; then
      echo "ERROR: Failed to create qdrant directory"
      exit 1
    fi
    
    # Create qdrant volume
    sudo docker volume create --name=qdrant_data
    if [ $? -ne 0 ]; then
      echo "ERROR: Failed to create qdrant volume"
      exit 1
    fi
    
    # Copy qdrant-docker-compose.yaml template to working file
    sudo cp qdrant-docker-compose.yaml.template /opt/qdrant/docker-compose.yaml
    if [ $? -ne 0 ]; then
      echo "ERROR: Failed to copy qdrant-docker-compose.yaml.template to working file"
      exit 1
    fi
    
    # Copy Caddyfile for qdrant
    sudo cp qdrant-Caddyfile.template /opt/qdrant/Caddyfile
    if [ $? -ne 0 ]; then
      echo "ERROR: Failed to copy qdrant-Caddyfile.template to /opt/qdrant/"
      exit 1
    fi
    
    echo "✅ Qdrant setup completed"
  fi
fi

# Create Caddyfile
echo "Creating Caddyfile..."
cat > Caddyfile << EOL
n8n.${DOMAIN_NAME} {
    reverse_proxy n8n:5678
}

flowise.${DOMAIN_NAME} {
    reverse_proxy flowise:3001
}

# Add Adminer to Caddyfile if enabled
if [[ "$INSTALL_ADMINER" == "true" ]]; then
cat >> Caddyfile << ADMINER_EOL

adminer.${DOMAIN_NAME} {
    reverse_proxy adminer:8080
}
ADMINER_EOL
fi
EOL
if [ $? -ne 0 ]; then
  echo "ERROR: Failed to create Caddyfile"
  exit 1
fi

# Copy file to working directory
sudo cp Caddyfile /opt/n8n/
if [ $? -ne 0 ]; then
  echo "ERROR: Failed to copy Caddyfile to /opt/n8n/"
  exit 1
fi

# Create monitoring files if monitoring is enabled
if [[ "$INSTALL_MONITORING" == "true" ]]; then
  echo "Creating monitoring configuration files..."
  
  # Create prometheus-docker-compose.yaml template
  if [ ! -f "../prometheus-docker-compose.yaml.template" ]; then
    echo "Creating template prometheus-docker-compose.yaml.template..."
    cat > prometheus-docker-compose.yaml.template << EOL
version: '3'

services:
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    restart: unless-stopped
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/usr/share/prometheus/console_libraries'
      - '--web.console.templates=/usr/share/prometheus/consoles'
    ports:
      - 9090:9090
    networks:
      - app-network

  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    restart: unless-stopped
    volumes:
      - grafana_data:/var/lib/grafana
      - ./grafana/provisioning:/etc/grafana/provisioning
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=\${GRAFANA_PASSWORD:-admin}
      - GF_USERS_ALLOW_SIGN_UP=false
      - GF_SERVER_DOMAIN=\${DOMAIN_NAME}
      - GF_SERVER_ROOT_URL=https://grafana.\${DOMAIN_NAME}
    ports:
      - 3000:3000
    networks:
      - app-network

  caddy:
    image: caddy:2
    container_name: monitoring-caddy
    restart: unless-stopped
    ports:
      - 9091:80
      - 9443:443
    volumes:
      - ./Caddyfile-monitoring:/etc/caddy/Caddyfile
      - caddy_monitoring_data:/data
      - caddy_monitoring_config:/config
    networks:
      - app-network

volumes:
  prometheus_data:
    external: true
  grafana_data:
    external: true
  caddy_monitoring_data:
  caddy_monitoring_config:

networks:
  app-network:
    external: true
EOL
    if [ $? -ne 0 ]; then
      echo "ERROR: Failed to create file prometheus-docker-compose.yaml.template"
      exit 1
    fi
  else
    echo "Template prometheus-docker-compose.yaml.template already exists"
  fi
  
  # Copy prometheus-docker-compose.yaml.template to working file
  cp prometheus-docker-compose.yaml.template ../prometheus-docker-compose.yaml
  if [ $? -ne 0 ]; then
    echo "ERROR: Failed to copy prometheus-docker-compose.yaml.template to working file"
    exit 1
  fi
  
  # Create prometheus.yml
  echo "Creating prometheus.yml..."
  cat > prometheus.yml << EOL
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
  
  - job_name: 'caddy'
    static_configs:
      - targets: ['caddy:2019']
  
  - job_name: 'n8n'
    static_configs:
      - targets: ['n8n:5678']

  - job_name: 'docker'
    static_configs:
      - targets: ['172.17.0.1:9323']

  - job_name: 'node-exporter'
    static_configs:
      - targets: ['node-exporter:9100']
EOL
  if [ $? -ne 0 ]; then
    echo "ERROR: Failed to create prometheus.yml"
    exit 1
  fi
  
  # Create Caddyfile-monitoring
  echo "Creating Caddyfile-monitoring..."
  cat > Caddyfile-monitoring << EOL
grafana.${DOMAIN_NAME} {
  reverse_proxy grafana:3000
  header Strict-Transport-Security max-age=31536000;
  log {
    output file /var/log/caddy/grafana_access.log {
      roll_size 10MB
      roll_keep 5
    }
  }
}

prometheus.${DOMAIN_NAME} {
  reverse_proxy prometheus:9090
  header Strict-Transport-Security max-age=31536000;
  basicauth {
    \${PROMETHEUS_USER} \${PROMETHEUS_HASHED_PASSWORD}
  }
  log {
    output file /var/log/caddy/prometheus_access.log {
      roll_size 10MB
      roll_keep 5
    }
  }
}
EOL
  if [ $? -ne 0 ]; then
    echo "ERROR: Failed to create Caddyfile-monitoring"
    exit 1
  fi
  
  # Create monitoring directories
  sudo mkdir -p /opt/monitoring/grafana/provisioning
  if [ $? -ne 0 ]; then
    echo "ERROR: Failed to create monitoring directories"
    exit 1
  fi
  
  # Copy monitoring files to working directory
  sudo cp prometheus.yml /opt/monitoring/
  if [ $? -ne 0 ]; then
    echo "ERROR: Failed to copy prometheus.yml to /opt/monitoring/"
    exit 1
  fi
  
  sudo cp Caddyfile-monitoring /opt/monitoring/
  if [ $? -ne 0 ]; then
    echo "ERROR: Failed to copy Caddyfile-monitoring to /opt/monitoring/"
    exit 1
  fi
  
  sudo cp ../prometheus-docker-compose.yaml /opt/monitoring/
  if [ $? -ne 0 ]; then
    echo "ERROR: Failed to copy prometheus-docker-compose.yaml to /opt/monitoring/"
    exit 1
  fi
  
  echo "✅ Monitoring configuration files successfully created"
fi

echo "✅ Templates and configuration files successfully created"
exit 0 
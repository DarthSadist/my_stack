#!/bin/bash

# Function to check successful command execution
check_success() {
  if [ $? -ne 0 ]; then
    echo "❌ Error executing $1"
    echo "Installation aborted. Please fix the errors and try again."
    exit 1
  fi
}

# Function to display progress
show_progress() {
  echo ""
  echo "========================================================"
  echo "   $1"
  echo "========================================================"
  echo ""
}

# Function to check DNS records for domain
check_dns() {
  echo "Проверка DNS-записей для домена $1..."
  IP=$(dig +short $1)
  if [ -z "$IP" ]; then
    echo "⚠️ Предупреждение: DNS-записи для домена $1 не настроены."
    echo "После установки сервисы не будут доступны до настройки DNS-записей."
    read -p "Продолжить установку? (y/n): " CONTINUE
    if [[ ! "$CONTINUE" =~ ^[Yy]$ ]]; then
      echo "Установка прервана."
      exit 1
    fi
  else
    echo "✅ DNS-записи настроены: $1 указывает на $IP"
  fi
}

# Main installation function
main() {
  show_progress "🚀 Starting installation of n8n, Flowise, and Caddy"
  
  # Check administrator rights
  if [ "$EUID" -ne 0 ]; then
    if ! sudo -n true 2>/dev/null; then
      echo "Administrator rights are required for installation"
      echo "Please enter the administrator password when prompted"
    fi
  fi
  
  # Request user data
  echo "For installation, you need to specify a domain name and email address."
  
  # Request domain name
  if [ -z "${DOMAIN_NAME:-}" ]; then
    read -p "Enter your domain name (e.g., example.com): " DOMAIN_NAME
    while [[ -z "$DOMAIN_NAME" ]]; do
      echo "Domain name cannot be empty"
      read -p "Enter your domain name (e.g., example.com): " DOMAIN_NAME
    done
  else
    echo "Using domain name from environment: $DOMAIN_NAME"
  fi
  
  # Check DNS records for the domain
  check_dns "$DOMAIN_NAME"
  
  # Request email address
  if [ -z "${USER_EMAIL:-}" ]; then
    read -p "Enter your email (will be used for n8n login): " USER_EMAIL
    while [[ ! "$USER_EMAIL" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; do
      echo "Enter a valid email address"
      read -p "Enter your email (will be used for n8n login): " USER_EMAIL
    done
  else
    echo "Using email from environment: $USER_EMAIL"
    if [[ ! "$USER_EMAIL" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
      echo "ERROR: Invalid email format in USER_EMAIL environment variable"
      exit 1
    fi
  fi
  
  # Request timezone
  DEFAULT_TIMEZONE=$(timedatectl show --property=Timezone --value 2>/dev/null || echo "UTC")
  if [ -z "${GENERIC_TIMEZONE:-}" ]; then
    read -p "Enter your timezone (default: $DEFAULT_TIMEZONE): " GENERIC_TIMEZONE
    GENERIC_TIMEZONE=${GENERIC_TIMEZONE:-$DEFAULT_TIMEZONE}
  else
    echo "Using timezone from environment: $GENERIC_TIMEZONE"
  fi
  
  # Ask if user wants to install monitoring system
  echo ""
  if [ -z "${INSTALL_MONITORING:-}" ]; then
    echo "Do you want to install Prometheus and Grafana monitoring system?"
    echo "This will provide metrics, dashboards, and monitoring for all services."
    read -p "Install monitoring system? (y/n, default: n): " INSTALL_MONITORING
    INSTALL_MONITORING=${INSTALL_MONITORING:-n}
  else
    echo "Using monitoring flag from environment: $INSTALL_MONITORING"
  fi
  if [[ "$INSTALL_MONITORING" =~ ^[Yy]$ ]]; then
    INSTALL_MONITORING=true
    echo "✅ Monitoring system will be installed"
  else
    INSTALL_MONITORING=false
    echo "⏩ Monitoring system will not be installed"
  fi
  
  # Ask if user wants to install PostgreSQL
  echo ""
  echo "Do you want to install PostgreSQL database?"
  echo "This will provide persistent storage for n8n and Flowise."
  if [ -z "${INSTALL_POSTGRES:-}" ]; then
    read -p "Install PostgreSQL? (y/n, default: n): " INSTALL_POSTGRES
    INSTALL_POSTGRES=${INSTALL_POSTGRES:-n}
  else
    echo "Using PostgreSQL flag from environment: $INSTALL_POSTGRES"
  fi
  if [[ "$INSTALL_POSTGRES" =~ ^[Yy]$ ]]; then
    INSTALL_POSTGRES=true
    echo "✅ PostgreSQL will be installed"
  else
    INSTALL_POSTGRES=false
    echo "⏩ PostgreSQL will not be installed"
  fi
  
  # Ask if user wants to install Redis
  echo ""
  echo "Do you want to install Redis cache?"
  echo "This will improve performance of n8n and Flowise."
  if [ -z "${INSTALL_REDIS:-}" ]; then
    read -p "Install Redis? (y/n, default: n): " INSTALL_REDIS
    INSTALL_REDIS=${INSTALL_REDIS:-n}
  else
    echo "Using Redis flag from environment: $INSTALL_REDIS"
  fi
  if [[ "$INSTALL_REDIS" =~ ^[Yy]$ ]]; then
    INSTALL_REDIS=true
    echo "✅ Redis will be installed"
  else
    INSTALL_REDIS=false
    echo "⏩ Redis will not be installed"
  fi
  
  # Ask if user wants to install Adminer
  echo ""
  echo "Do you want to install Adminer database management tool?"
  echo "This will provide web interface for PostgreSQL database management."
  if [ -z "${INSTALL_ADMINER:-}" ]; then
    read -p "Install Adminer? (y/n, default: n): " INSTALL_ADMINER
    INSTALL_ADMINER=${INSTALL_ADMINER:-n}
  else
    echo "Using Adminer flag from environment: $INSTALL_ADMINER"
  fi
  if [[ "$INSTALL_ADMINER" =~ ^[Yy]$ ]]; then
    INSTALL_ADMINER=true
    if [[ "$INSTALL_POSTGRES" != "true" ]]; then
      echo "⚠️ Warning: Adminer requires PostgreSQL. PostgreSQL will be installed as well."
      INSTALL_POSTGRES=true
    fi
    echo "✅ Adminer will be installed"
  else
    INSTALL_ADMINER=false
    echo "⏩ Adminer will not be installed"
  fi
  
  # Ask if user wants to install Qdrant
  echo ""
  echo "Do you want to install Qdrant vector database?"
  echo "This will provide vector storage and similarity search capabilities for n8n and Flowise."
  if [ -z "${INSTALL_QDRANT:-}" ]; then
    read -p "Install Qdrant? (y/n, default: n): " INSTALL_QDRANT
    INSTALL_QDRANT=${INSTALL_QDRANT:-n}
  else
    echo "Using Qdrant flag from environment: $INSTALL_QDRANT"
  fi
  if [[ "$INSTALL_QDRANT" =~ ^[Yy]$ ]]; then
    INSTALL_QDRANT=true
    echo "✅ Qdrant will be installed"
  else
    INSTALL_QDRANT=false
    echo "⏩ Qdrant will not be installed"
  fi
  
  # Create setup-files directory if it doesn't exist
  if [ ! -d "setup-files" ]; then
    mkdir -p setup-files
    check_success "creating setup-files directory"
  fi
  
  # Set execution permissions for all scripts
  chmod +x setup-files/*.sh 2>/dev/null || true
  
  # Step 1: System update
  show_progress "Step 1/7: System update"
  ./setup-files/01-update-system.sh
  check_success "system update"
  
  # Step 2: Docker installation
  show_progress "Step 2/7: Docker installation"
  ./setup-files/02-install-docker.sh
  check_success "Docker installation"
  
  # Step 3: Directory setup
  show_progress "Step 3/7: Directory setup"
  ./setup-files/03-setup-directories.sh
  check_success "directory setup"
  
  # Step 4: Secret key generation
  show_progress "Step 4/7: Secret key generation"
  ./setup-files/04-generate-secrets.sh "$USER_EMAIL" "$DOMAIN_NAME" "$GENERIC_TIMEZONE" "$INSTALL_MONITORING" "$INSTALL_POSTGRES" "$INSTALL_REDIS" "$INSTALL_ADMINER" "$INSTALL_QDRANT"
  check_success "secret key generation"
  
  # Step 5: Template creation
  show_progress "Step 5/7: Configuration file creation"
  ./setup-files/05-create-templates.sh "$DOMAIN_NAME" "$INSTALL_MONITORING" "$INSTALL_POSTGRES" "$INSTALL_REDIS" "$INSTALL_ADMINER" "$INSTALL_QDRANT"
  check_success "configuration file creation"
  
  # Step 6: Firewall setup
  show_progress "Step 6/7: Firewall setup"
  ./setup-files/06-setup-firewall.sh
  check_success "firewall setup"
  
  # Step 7: Service launch
  show_progress "Step 7/7: Service launch"
  ./setup-files/07-start-services.sh
  check_success "service launch"
  
  # Load generated passwords
  N8N_PASSWORD=""
  FLOWISE_PASSWORD=""
  GRAFANA_PASSWORD=""
  PROMETHEUS_USER=""
  PROMETHEUS_PASSWORD=""
  if [ -f "./setup-files/passwords.txt" ]; then
    source ./setup-files/passwords.txt
  fi
  
  # Installation successfully completed
  show_progress "✅ Installation successfully completed!"
  
  echo "n8n is available at: https://n8n.${DOMAIN_NAME}"
  echo "Flowise is available at: https://flowise.${DOMAIN_NAME}"
  echo ""
  echo "Login credentials for n8n:"
  echo "Email: ${USER_EMAIL}"
  echo "Password: ${N8N_PASSWORD:-<check the .env file>}"
  echo ""
  echo "Login credentials for Flowise:"
  echo "Username: admin"
  echo "Password: ${FLOWISE_PASSWORD:-<check the .env file>}"
  echo ""
  echo "Please note that for the domain name to work, you need to configure DNS records"
  echo "pointing to the IP address of this server."
  echo ""
  echo "To edit the configuration, use the following files:"
  echo "- n8n-docker-compose.yaml (n8n and Caddy configuration)"
  echo "- flowise-docker-compose.yaml (Flowise configuration)"
  echo "- .env (environment variables for all services)"
  echo "- Caddyfile (reverse proxy settings)"
  echo ""
  echo "To restart services, execute the commands:"
  echo "docker compose -f n8n-docker-compose.yaml restart"
  echo "docker compose -f flowise-docker-compose.yaml restart"
  
  # Show monitoring information if installed
  if [[ "$INSTALL_MONITORING" == "true" ]]; then
    echo ""
    echo "Monitoring system is available at:"
    echo "Grafana: https://grafana.${DOMAIN_NAME}"
    echo "Prometheus: https://prometheus.${DOMAIN_NAME}"
    echo ""
    echo "Login credentials for Grafana:"
    echo "Username: admin"
    echo "Password: ${GRAFANA_PASSWORD:-<check the monitoring.env file>}"
    echo ""
    echo "Login credentials for Prometheus:"
    echo "Username: ${PROMETHEUS_USER:-<check the monitoring.env file>}"
    echo "Password: ${PROMETHEUS_PASSWORD:-<check the monitoring.env file>}"
    echo ""
    echo "To restart monitoring services, execute the command:"
    echo "docker compose -f prometheus-docker-compose.yaml restart"
  fi
}

# Run main function
main 
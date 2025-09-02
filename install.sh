#!/bin/bash
set -e

# 🚀 QDYNN-SERVER Автоматическая установка
# Разворачивает DNSTT туннель-сервер одной командой

VERSION="1.0.0"
REPO_URL="https://github.com/stepan163/qdynn-server"
INSTALL_DIR="/opt/qdynn-server"
BIN_DIR="/usr/local/bin"
CONFIG_DIR="/etc/qdynn"
LOG_DIR="/var/log/qdynn"
SERVICE_NAME="qdynn-server"

# Цвета для красивого вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Функция для красивого логирования
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[⚠]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
    exit 1
}

log_header() {
    echo -e "\n${PURPLE}▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓${NC}"
    echo -e "${WHITE}  🚀 QDYNN-SERVER v$VERSION - Автоматическая установка${NC}"
    echo -e "${CYAN}     Ядро: DNSTT Server от David Fifield (bamsoftware.com)${NC}"
    echo -e "${PURPLE}▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓${NC}\n"
}

# Проверка прав root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "Этот скрипт должен запускаться с правами root (sudo)"
    fi
    log_success "Права root подтверждены"
}

# Определение операционной системы
detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$NAME
        VER=$VERSION_ID
    else
        log_error "Не удалось определить операционную систему"
    fi
    
    log_info "Операционная система: $OS $VER"
    
    if [[ "$OS" != "Ubuntu" ]] && [[ "$OS" != "Debian GNU/Linux" ]]; then
        log_warning "Поддерживаются только Ubuntu и Debian. Продолжаем на свой страх и риск..."
    fi
}

# Обновление системы и установка зависимостей
install_dependencies() {
    log_info "Обновляем систему и устанавливаем зависимости..."
    
    apt-get update -q > /dev/null 2>&1
    apt-get install -y \
        curl \
        wget \
        git \
        golang-go \
        build-essential \
        systemd \
        certbot \
        python3-certbot-nginx \
        nginx \
        jq \
        qrencode \
        unzip \
        > /dev/null 2>&1
        
    log_success "Зависимости установлены"
}

# Создание пользователя и директорий
setup_directories() {
    log_info "Создаем пользователя и директории..."
    
    # Создаем пользователя qdynn
    if ! id "qdynn" &>/dev/null; then
        useradd -r -s /bin/false -d /opt/qdynn-server -c "QDYNN Server" qdynn
        log_success "Пользователь qdynn создан"
    fi
    
    # Создаем директории
    mkdir -p $INSTALL_DIR $CONFIG_DIR $LOG_DIR
    mkdir -p $INSTALL_DIR/{bin,configs,logs,scripts,certs}
    
    # Устанавливаем права доступа
    chown -R qdynn:qdynn $INSTALL_DIR $CONFIG_DIR $LOG_DIR
    chmod 750 $INSTALL_DIR $CONFIG_DIR
    chmod 755 $LOG_DIR
    
    log_success "Директории созданы и настроены"
}

# Скачивание и компиляция DNSTT
install_dnstt() {
    log_info "Скачиваем и компилируем DNSTT..."
    
    cd /tmp
    git clone https://www.bamsoftware.com/git/dnstt.git > /dev/null 2>&1
    cd dnstt
    
    # Компилируем сервер
    go build -o dnstt-server ./dnstt-server > /dev/null 2>&1
    
    # Копируем в установочную директорию
    cp dnstt-server $INSTALL_DIR/bin/
    chmod +x $INSTALL_DIR/bin/dnstt-server
    
    # Очищаем временные файлы
    cd /
    rm -rf /tmp/dnstt
    
    log_success "DNSTT сервер установлен"
}

# Создание CLI команды
create_cli() {
    log_info "Создаем CLI интерфейс..."
    
    cat > $BIN_DIR/qdynn << 'EOF'
#!/bin/bash
# QDYNN-SERVER CLI Interface

VERSION="1.0.0"
INSTALL_DIR="/opt/qdynn-server"
CONFIG_DIR="/etc/qdynn" 
LOG_DIR="/var/log/qdynn"
SERVICE_NAME="qdynn-server"

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

source $INSTALL_DIR/scripts/cli-functions.sh

case "$1" in
    start)     start_server ;;
    stop)      stop_server ;;
    restart)   restart_server ;;
    status)    show_status ;;
    logs)      show_logs "${2:-50}" ;;
    config)    configure_server "$2" "$3" ;;
    clients)   manage_clients "$2" "$3" ;;
    update)    update_server ;;
    *)         show_help ;;
esac
EOF
    
    chmod +x $BIN_DIR/qdynn
    log_success "CLI команда создана: qdynn"
}

# Создание systemd сервиса
create_service() {
    log_info "Создаем systemd сервис..."
    
    cat > /etc/systemd/system/$SERVICE_NAME.service << EOF
[Unit]
Description=QDYNN DNSTT Tunnel Server
After=network.target
Wants=network.target

[Service]
Type=simple
User=qdynn
Group=qdynn
WorkingDirectory=$INSTALL_DIR
ExecStart=$INSTALL_DIR/scripts/start-server.sh
ExecStop=$INSTALL_DIR/scripts/stop-server.sh
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

# Безопасность
NoNewPrivileges=yes
ProtectSystem=strict
ProtectHome=yes
ReadWritePaths=$CONFIG_DIR $LOG_DIR $INSTALL_DIR

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable $SERVICE_NAME > /dev/null 2>&1
    
    log_success "Systemd сервис создан и активирован"
}

# Генерация начальной конфигурации
generate_config() {
    log_info "Генерируем начальную конфигурацию..."
    
    # Генерируем ключи
    PRIVATE_KEY=$(openssl rand -hex 32)
    PUBLIC_KEY=$(echo -n $PRIVATE_KEY | xxd -r -p | openssl dgst -sha256 -binary | xxd -p -c 32)
    
    # Получаем внешний IP
    EXTERNAL_IP=$(curl -s ifconfig.me || curl -s ipinfo.io/ip || echo "YOUR_SERVER_IP")
    
    cat > $CONFIG_DIR/server.conf << EOF
# QDYNN Server Configuration
SERVER_DOMAIN="tunnel.$(hostname -f 2>/dev/null || echo 'example.com')"
EXTERNAL_IP="$EXTERNAL_IP"
DNS_PORT="53"
HTTPS_PORT="443"
PRIVATE_KEY="$PRIVATE_KEY"
PUBLIC_KEY="$PUBLIC_KEY"
MAX_CLIENTS="100"
LOG_LEVEL="INFO"
ENABLE_SSL="true"
AUTO_UPDATE="true"
EOF
    
    chown qdynn:qdynn $CONFIG_DIR/server.conf
    chmod 640 $CONFIG_DIR/server.conf
    
    log_success "Конфигурация сгенерирована"
}

# Финальная настройка
finalize_installation() {
    log_info "Завершаем установку..."
    
    # Создаем скрипты
    $INSTALL_DIR/scripts/create-scripts.sh
    
    # Устанавливаем права
    chown -R qdynn:qdynn $INSTALL_DIR
    
    log_success "Установка завершена!"
    
    echo -e "\n${GREEN}╔════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║           УСТАНОВКА ЗАВЕРШЕНА!         ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════╝${NC}\n"
    
    echo -e "${CYAN}Следующие шаги:${NC}"
    echo -e "1. ${YELLOW}qdynn config domain your-domain.com${NC} - настроить домен"
    echo -e "2. ${YELLOW}qdynn start${NC} - запустить сервер"
    echo -e "3. ${YELLOW}qdynn status${NC} - получить данные для подключения\n"
    
    echo -e "${BLUE}Документация:${NC} https://github.com/stepan163/qdynn-server"
    echo -e "${BLUE}Поддержка:${NC} https://t.me/qdynn_support\n"
}

# Главная функция
main() {
    log_header
    check_root
    detect_os
    install_dependencies
    setup_directories
    install_dnstt
    create_cli
    create_service
    generate_config
    finalize_installation
}

# Запуск установки
main "$@"

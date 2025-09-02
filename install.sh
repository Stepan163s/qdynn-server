#!/bin/bash
set -e

# 🚀 QDYNN-SERVER Автоматическая установка
# Разворачивает DNSTT туннель-сервер одной командой

VERSION="1.0.0"
REPO_URL="https://github.com/Stepan163s/qdynn-server"
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

# Настройки отладки
# Включить: curl -fsSL .../install.sh | sudo bash -s -- --debug
# Или экспортировать QDYNN_DEBUG=1
IS_DEBUG=0
# В обычном режиме подавляем шумный вывод команд
QUIET="> /dev/null 2>&1"

# Требуемая версия Go и версия для установки
GO_MIN_VERSION="1.21.0"
GO_INSTALL_VERSION="1.22.5"

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

# Разбор флагов CLI и включение режима отладки при необходимости
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --debug|-d)
                IS_DEBUG=1
                ;;
        esac
        shift
    done

    if [[ -n "${QDYNN_DEBUG:-}" ]] || { [[ -n "${DEBUG:-}" ]] && [[ "${DEBUG}" != "0" ]]; }; then
        IS_DEBUG=1
    fi

    if [[ "$IS_DEBUG" -eq 1 ]]; then
        QUIET=""
        set -o pipefail
        set -x
        echo -e "${YELLOW}[⚠]${NC} DEBUG режим включен: вывод команд и ошибок не подавляется"
        trap 'echo -e "${RED}[✗]${NC} Ошибка на строке $LINENO: команда: ${BASH_COMMAND}"' ERR
    fi
}

# Проверка и установка Go (если отсутствует или версия ниже минимальной)
ensure_go() {
    local has_go=0
    local current_ver=""
    if command -v go >/dev/null 2>&1; then
        has_go=1
        current_ver=$(go version | awk '{print $3}' | sed 's/^go//')
    fi

    if [[ "$has_go" -eq 1 ]]; then
        if dpkg --compare-versions "$current_ver" ge "$GO_MIN_VERSION"; then
            log_success "Go найден: версия $current_ver (достаточно)"
            return 0
        else
            log_warning "Обнаружен Go $current_ver (< $GO_MIN_VERSION). Выполняем обновление..."
        fi
    else
        log_info "Go не найден. Устанавливаем Go $GO_INSTALL_VERSION..."
    fi

    install_go
}

install_go() {
    # Определяем архитектуру
    local arch
    case "$(uname -m)" in
        x86_64|amd64)
            arch="amd64" ;;
        aarch64|arm64)
            arch="arm64" ;;
        *)
            log_error "Неподдерживаемая архитектура: $(uname -m). Поддерживаются amd64 и arm64."
            ;;
    esac

    local tar_name="go${GO_INSTALL_VERSION}.linux-${arch}.tar.gz"
    local url="https://go.dev/dl/${tar_name}"
    log_info "Скачиваем Go ${GO_INSTALL_VERSION} (${arch})..."
    curl -fsSL "$url" -o "/tmp/${tar_name}" || log_error "Не удалось скачать ${url}"

    log_info "Устанавливаем Go в /usr/local ..."
    rm -rf /usr/local/go
    tar -C /usr/local -xzf "/tmp/${tar_name}" $QUIET
    ln -sf /usr/local/go/bin/go /usr/local/bin/go
    ln -sf /usr/local/go/bin/gofmt /usr/local/bin/gofmt

    # Экспортируем PATH для будущих сессий
    cat > /etc/profile.d/go.sh << 'EOF'
export PATH="$PATH:/usr/local/go/bin"
EOF

    # Проверяем результат
    if command -v go >/dev/null 2>&1; then
        local new_ver
        new_ver=$(go version | awk '{print $3}' | sed 's/^go//')
        log_success "Go установлен: версия ${new_ver}"
    else
        log_error "Go не найден после установки"
    fi
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
    
    apt-get update -q $QUIET
    apt-get install -y \
        curl \
        wget \
        git \
        build-essential \
        systemd \
        certbot \
        python3-certbot-nginx \
        nginx \
        jq \
        qrencode \
        unzip \
        $QUIET
        
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
    # Если каталог уже существует (повторная установка) — удаляем
    if [[ -d "dnstt" ]]; then
        log_warning "Обнаружена существующая директория dnstt. Удаляем..."
        rm -rf dnstt
    fi
    git clone https://www.bamsoftware.com/git/dnstt.git $QUIET
    cd dnstt
    
    # Компилируем сервер
    local go_build_flags=""
    if [[ "$IS_DEBUG" -eq 1 ]]; then
        go_build_flags="-v"
    fi
    GO111MODULE=on go build ${go_build_flags} -o dnstt-server ./dnstt-server $QUIET
    
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
    systemctl enable $SERVICE_NAME $QUIET
    
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
    
    echo -e "${BLUE}Документация:${NC} https://github.com/Stepan163s/qdynn-server"
    echo -e "${BLUE}Поддержка:${NC} https://t.me/qdynn_support\n"
}

# Главная функция
main() {
    parse_args "$@"
    log_header
    check_root
    detect_os
    install_dependencies
    ensure_go
    setup_directories
    install_dnstt
    create_cli
    create_service
    generate_config
    finalize_installation
}

# Запуск установки
main "$@"

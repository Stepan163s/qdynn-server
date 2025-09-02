#!/bin/bash
# QDYNN-SERVER Update Script

set -e

VERSION="1.0.0"
INSTALL_DIR="/opt/qdynn-server"
CONFIG_DIR="/etc/qdynn"
LOG_DIR="/var/log/qdynn"
SERVICE_NAME="qdynn-server"
BACKUP_DIR="/tmp/qdynn-backup-$(date +%Y%m%d-%H%M%S)"

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# Минимальная и целевая версии Go
GO_MIN_VERSION="1.21.0"
GO_INSTALL_VERSION="1.22.5"

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
    echo -e "${WHITE}  🔄 QDYNN-SERVER v$VERSION - Обновление системы${NC}"
    echo -e "${PURPLE}▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓${NC}\n"
}

# Проверка прав и установка Go при необходимости
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
    tar -C /usr/local -xzf "/tmp/${tar_name}" >/dev/null 2>&1 || true
    ln -sf /usr/local/go/bin/go /usr/local/bin/go
    ln -sf /usr/local/go/bin/gofmt /usr/local/bin/gofmt

    cat > /etc/profile.d/go.sh << 'EOF'
export PATH="$PATH:/usr/local/go/bin"
EOF

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
        log_error "Обновление требует права root (sudo)"
    fi
}

# Создание резервной копии
create_backup() {
    log_info "Создаем резервную копию..."
    
    mkdir -p $BACKUP_DIR
    
    # Копируем конфигурацию
    if [[ -d "$CONFIG_DIR" ]]; then
        cp -r $CONFIG_DIR $BACKUP_DIR/configs
    fi
    
    # Копируем логи
    if [[ -d "$LOG_DIR" ]]; then
        cp -r $LOG_DIR $BACKUP_DIR/logs
    fi
    
    # Копируем важные файлы
    if [[ -f "$INSTALL_DIR/VERSION" ]]; then
        cp $INSTALL_DIR/VERSION $BACKUP_DIR/
    fi
    
    log_success "Резервная копия создана: $BACKUP_DIR"
}

# Остановка сервиса
stop_service() {
    log_info "Останавливаем QDYNN Server..."
    
    if systemctl is-active --quiet $SERVICE_NAME; then
        systemctl stop $SERVICE_NAME
        log_success "Сервис остановлен"
    else
        log_info "Сервис уже остановлен"
    fi
}

# Обновление DNSTT
update_dnstt() {
    log_info "Обновляем DNSTT до последней версии..."
    
    cd /tmp
    # Удаляем старую директорию, если осталась от предыдущего запуска
    if [[ -d "dnstt-update" ]]; then
        log_warning "Обнаружена существующая директория dnstt-update. Удаляем..."
        rm -rf dnstt-update
    fi
    git clone https://www.bamsoftware.com/git/dnstt.git dnstt-update > /dev/null 2>&1
    cd dnstt-update
    
    # Компилируем новую версию (имя файла, чтобы не конфликтовать с каталогом)
    go build -o dnstt-server.bin ./dnstt-server > /dev/null 2>&1
    if [[ ! -f dnstt-server.bin ]]; then
        log_error "Сборка DNSTT не удалась: бинарник не найден"
    fi
    
    # Заменяем старую версию
    cp dnstt-server.bin $INSTALL_DIR/bin/dnstt-server
    chmod +x $INSTALL_DIR/bin/dnstt-server
    
    # Очищаем временные файлы
    cd /
    rm -rf /tmp/dnstt-update
    
    log_success "DNSTT обновлен"
}

# Обновление скриптов
update_scripts() {
    log_info "Обновляем скрипты системы..."
    
    # Скачиваем новые версии скриптов
    local temp_dir="/tmp/qdynn-scripts-update"
    mkdir -p $temp_dir
    
    # GitHub Raw URLs для скриптов
    curl -fsSL "https://raw.githubusercontent.com/Stepan163s/qdynn-server/main/scripts/cli-functions.sh" \
         -o $temp_dir/cli-functions.sh
    curl -fsSL "https://raw.githubusercontent.com/Stepan163s/qdynn-server/main/scripts/create-scripts.sh" \
         -o $temp_dir/create-scripts.sh
    
    # Обновляем скрипты
    cp $temp_dir/*.sh $INSTALL_DIR/scripts/
    chmod +x $INSTALL_DIR/scripts/*.sh
    
    # Пересоздаем служебные скрипты
    $INSTALL_DIR/scripts/create-scripts.sh
    
    rm -rf $temp_dir
    log_success "Скрипты обновлены"
}

# Обновление CLI
update_cli() {
    log_info "Обновляем CLI интерфейс..."
    
    # Генерируем CLI локально, как в install.sh
    cat > /usr/local/bin/qdynn << 'EOF'
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
    
    chmod +x /usr/local/bin/qdynn
    log_success "CLI обновлен"
}

# Обновление конфигурации (с сохранением пользовательских настроек)
update_config() {
    log_info "Обновляем конфигурацию..."
    
    # Если есть старая конфигурация, мигрируем ее
    if [[ -f "$CONFIG_DIR/server.conf" ]]; then
        # Создаем новую конфигурацию с сохранением старых значений
        local temp_config="/tmp/server.conf.new"
        
        # Скачиваем новый шаблон
        curl -fsSL "https://raw.githubusercontent.com/Stepan163s/qdynn-server/main/configs/server.conf.template" \
             -o $temp_config
        
        # Переносим старые значения
        source "$CONFIG_DIR/server.conf"
        
        sed -i "s/SERVER_DOMAIN=.*/SERVER_DOMAIN=\"$SERVER_DOMAIN\"/" $temp_config
        sed -i "s/EXTERNAL_IP=.*/EXTERNAL_IP=\"$EXTERNAL_IP\"/" $temp_config
        sed -i "s/PRIVATE_KEY=.*/PRIVATE_KEY=\"$PRIVATE_KEY\"/" $temp_config
        sed -i "s/PUBLIC_KEY=.*/PUBLIC_KEY=\"$PUBLIC_KEY\"/" $temp_config
        sed -i "s/MAX_CLIENTS=.*/MAX_CLIENTS=\"$MAX_CLIENTS\"/" $temp_config
        
        # Заменяем старую конфигурацию
        cp $temp_config $CONFIG_DIR/server.conf
        rm $temp_config
        
        log_success "Конфигурация обновлена с сохранением пользовательских настроек"
    else
        log_warning "Конфигурация не найдена, создается новая"
        # Генерируем новую конфигурацию как при первой установке
        generate_new_config
    fi
}

# Генерация новой конфигурации
generate_new_config() {
    PRIVATE_KEY=$(openssl rand -hex 32)
    PUBLIC_KEY=$(echo -n $PRIVATE_KEY | xxd -r -p | openssl dgst -sha256 -binary | xxd -p -c 32)
    EXTERNAL_IP=$(curl -s ifconfig.me || curl -s ipinfo.io/ip || echo "YOUR_SERVER_IP")
    
    cat > $CONFIG_DIR/server.conf << EOF
SERVER_DOMAIN="tunnel.$(hostname -f 2>/dev/null || echo 'example.com')"
EXTERNAL_IP="$EXTERNAL_IP"
DNS_PORT="53"
HTTPS_PORT="443"
PRIVATE_KEY="$PRIVATE_KEY"
PUBLIC_KEY="$PUBLIC_KEY"
MAX_CLIENTS="100"
LOG_LEVEL="INFO"
ENABLE_SSL="true"
AUTO_UPDATE="false"
EOF
    
    chown qdynn:qdynn $CONFIG_DIR/server.conf
    chmod 640 $CONFIG_DIR/server.conf
}

# Запуск сервиса
start_service() {
    log_info "Запускаем QDYNN Server..."

    # Ротация логов перед запуском, чтобы не было путаницы
    ts=$(date +%Y%m%d-%H%M%S)
    for f in dnstt.log server.log monitor.log update.log; do
        if [[ -s "$LOG_DIR/$f" ]]; then
            mv "$LOG_DIR/$f" "$LOG_DIR/${f%.log}-$ts.log"
        fi
        : > "$LOG_DIR/$f"
    done
    find "$LOG_DIR" -type f -name "*-*.log" -mtime +14 -delete 2>/dev/null || true

    systemctl daemon-reload
    # Обновляем юнит: даём права на порт 53 и логи
    if grep -q "ExecStart=/opt/qdynn-server/scripts/start-server.sh" /etc/systemd/system/qdynn-server.service 2>/dev/null; then
        sed -i 's/^\s*AmbientCapabilities.*/AmbientCapabilities=CAP_NET_BIND_SERVICE/g' /etc/systemd/system/qdynn-server.service 2>/dev/null || true
        sed -i 's/^\s*CapabilityBoundingSet.*/CapabilityBoundingSet=CAP_NET_BIND_SERVICE/g' /etc/systemd/system/qdynn-server.service 2>/dev/null || true
        sed -i 's/^\s*LogsDirectory.*/LogsDirectory=qdynn/g' /etc/systemd/system/qdynn-server.service 2>/dev/null || true
        if ! grep -q '^LogsDirectory=qdynn' /etc/systemd/system/qdynn-server.service 2>/dev/null; then
            sed -i '/^ReadWritePaths=/a LogsDirectory=qdynn' /etc/systemd/system/qdynn-server.service 2>/dev/null || true
        fi
        if ! grep -q '^AmbientCapabilities=CAP_NET_BIND_SERVICE' /etc/systemd/system/qdynn-server.service 2>/dev/null; then
            sed -i '/^# Безопасность/a AmbientCapabilities=CAP_NET_BIND_SERVICE\nCapabilityBoundingSet=CAP_NET_BIND_SERVICE' /etc/systemd/system/qdynn-server.service 2>/dev/null || true
        fi
    fi
    systemctl start $SERVICE_NAME
    
    if systemctl is-active --quiet $SERVICE_NAME; then
        log_success "Сервис успешно запущен"
    else
        log_error "Ошибка запуска сервиса"
    fi
}

# Обновление версии
update_version() {
    echo "$VERSION" > $INSTALL_DIR/VERSION
    chown qdynn:qdynn $INSTALL_DIR/VERSION
}

# Очистка временных файлов
cleanup() {
    log_info "Очищаем временные файлы..."
    
    # Удаляем старые бэкапы (старше 30 дней)
    find /tmp -name "qdynn-backup-*" -type d -mtime +30 -exec rm -rf {} + 2>/dev/null || true
    
    log_success "Очистка завершена"
}

# Проверка целостности после обновления
verify_update() {
    log_info "Проверяем целостность обновления..."
    
    # Проверяем наличие важных файлов
    local files_to_check=(
        "$INSTALL_DIR/bin/dnstt-server"
        "$CONFIG_DIR/server.conf"
        "/usr/local/bin/qdynn"
        "$INSTALL_DIR/scripts/cli-functions.sh"
    )
    
    for file in "${files_to_check[@]}"; do
        if [[ ! -f "$file" ]]; then
            log_error "Отсутствует важный файл: $file"
        fi
    done
    
    # Проверяем статус сервиса
    if systemctl is-active --quiet $SERVICE_NAME; then
        log_success "Сервис работает корректно"
    else
        log_warning "Сервис не запущен, проверьте конфигурацию"
    fi
    
    log_success "Проверка целостности завершена"
}

# Главная функция
main() {
    log_header
    check_root
    create_backup
    stop_service
    ensure_go
    update_dnstt
    update_scripts
    update_cli
    update_config
    update_version
    start_service
    verify_update
    cleanup
    
    echo -e "\n${GREEN}╔════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║         ОБНОВЛЕНИЕ ЗАВЕРШЕНО!          ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════╝${NC}\n"
    
    echo -e "${CYAN}Что нового:${NC}"
    echo -e "• Обновлен DNSTT до последней версии"
    echo -e "• Улучшена система мониторинга"  
    echo -e "• Исправлены найденные ошибки"
    echo -e "• Добавлены новые функции CLI"
    
    echo -e "\n${BLUE}Резервная копия:${NC} $BACKUP_DIR"
    echo -e "${BLUE}Проверить статус:${NC} qdynn status"
    echo -e "${BLUE}Посмотреть логи:${NC} qdynn logs\n"
}

# Запуск обновления
main "$@"

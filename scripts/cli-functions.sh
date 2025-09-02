#!/bin/bash
# QDYNN-SERVER CLI Functions

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# Функции логирования
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
}

# Красивый заголовок
show_banner() {
    echo -e "\n${PURPLE}▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓${NC}"
    echo -e "${WHITE}         🚀 QDYNN-SERVER Control Panel v$VERSION${NC}"
    echo -e "${CYAN}            Powered by DNSTT (David Fifield)${NC}"
    echo -e "${PURPLE}▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓${NC}\n"
}

# Запуск сервера
start_server() {
    show_banner
    log_info "Запускаем QDYNN Server..."
    
    if systemctl is-active --quiet $SERVICE_NAME; then
        log_warning "Сервер уже запущен!"
        show_status
        return 0
    fi
    
    # Проверяем конфигурацию
    if [[ ! -f "$CONFIG_DIR/server.conf" ]]; then
        log_error "Конфигурация не найдена! Запустите: qdynn config setup"
    fi
    
    systemctl start $SERVICE_NAME
    
    if systemctl is-active --quiet $SERVICE_NAME; then
        log_success "Сервер успешно запущен!"
        sleep 2
        show_status
    else
        log_error "Ошибка запуска сервера. Проверьте логи: qdynn logs"
    fi
}

# Остановка сервера
stop_server() {
    show_banner
    log_info "Останавливаем QDYNN Server..."
    
    if ! systemctl is-active --quiet $SERVICE_NAME; then
        log_warning "Сервер уже остановлен!"
        return 0
    fi
    
    systemctl stop $SERVICE_NAME
    
    if ! systemctl is-active --quiet $SERVICE_NAME; then
        log_success "Сервер успешно остановлен!"
    else
        log_error "Ошибка остановки сервера"
    fi
}

# Перезапуск сервера
restart_server() {
    show_banner
    log_info "Перезапускаем QDYNN Server..."
    
    systemctl restart $SERVICE_NAME
    
    if systemctl is-active --quiet $SERVICE_NAME; then
        log_success "Сервер успешно перезапущен!"
        sleep 2
        show_status
    else
        log_error "Ошибка перезапуска сервера. Проверьте логи: qdynn logs"
    fi
}

# Показать статус и данные подключения
show_status() {
    show_banner
    
    # Загружаем конфигурацию
    if [[ -f "$CONFIG_DIR/server.conf" ]]; then
        source "$CONFIG_DIR/server.conf"
    else
        log_error "Файл конфигурации не найден!"
        return 1
    fi
    
    # Статус сервиса
    if systemctl is-active --quiet $SERVICE_NAME; then
        STATUS="${GREEN}🟢 АКТИВЕН${NC}"
    else
        STATUS="${RED}🔴 НЕАКТИВЕН${NC}"
    fi
    
    echo -e "${CYAN}╔══════════════════ СТАТУС СЕРВЕРА ══════════════════╗${NC}"
    echo -e "${CYAN}║${NC} Состояние: $STATUS"
    echo -e "${CYAN}║${NC} Домен:     ${YELLOW}$SERVER_DOMAIN${NC}"
    echo -e "${CYAN}║${NC} IP адрес:  ${YELLOW}$EXTERNAL_IP${NC}"
    echo -e "${CYAN}║${NC} DNS порт:  ${YELLOW}$DNS_PORT${NC}"
    echo -e "${CYAN}║${NC} Клиенты:   ${YELLOW}$(get_client_count)${NC}/${YELLOW}$MAX_CLIENTS${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════╝${NC}\n"
    
    if systemctl is-active --quiet $SERVICE_NAME; then
        echo -e "${GREEN}╔═══════════ ДАННЫЕ ДЛЯ ПОДКЛЮЧЕНИЯ ════════════╗${NC}"
        echo -e "${GREEN}║${NC} Публичный ключ:"
        echo -e "${GREEN}║${NC} ${WHITE}$PUBLIC_KEY${NC}"
        echo -e "${GREEN}║${NC}"
        echo -e "${GREEN}║${NC} Домен туннеля:"
        echo -e "${GREEN}║${NC} ${WHITE}ns.$SERVER_DOMAIN${NC}"
        echo -e "${GREEN}║${NC}"
        echo -e "${GREEN}║${NC} DoH Resolver:"
        echo -e "${GREEN}║${NC} ${WHITE}https://cloudflare-dns.com/dns-query${NC}"
        echo -e "${GREEN}╚══════════════════════════════════════════════════╝${NC}\n"
        
        # Генерируем QR-код для мобильного приложения
        generate_qr_code
        
        echo -e "${BLUE}💡 Скопируйте эти данные в мобильное приложение QDYNN${NC}"
    fi
}

# Генерация QR-кода
generate_qr_code() {
    local config_json='{
        "transport": "doh",
        "resolver": "https://cloudflare-dns.com/dns-query",
        "pubkey": "'$PUBLIC_KEY'",
        "domain": "ns.'$SERVER_DOMAIN'",
        "local_addr": "127.0.0.1:12345"
    }'
    
    echo -e "${CYAN}QR-код для быстрого подключения:${NC}"
    echo "$config_json" | qrencode -t ANSIUTF8 -s 1 -m 1
    echo ""
}

# Показать логи
show_logs() {
    local arg=${1:-50}
    if [[ "$arg" == "clear" ]]; then
        clear_logs
        return 0
    fi
    local lines="$arg"
    show_banner
    
    echo -e "${CYAN}════════════ ЛОГИ СЕРВЕРА (последние $lines строк) ═══════════=${NC}\n"
    
    if systemctl is-active --quiet $SERVICE_NAME; then
        journalctl -u $SERVICE_NAME -n $lines --no-pager -f
    else
        journalctl -u $SERVICE_NAME -n $lines --no-pager
    fi
}

# Очистка/ротация логов вручную
clear_logs() {
    show_banner
    log_info "Останавливаем сервис для очистки логов..."
    systemctl stop $SERVICE_NAME 2>/dev/null || true
    
    local ts
    ts=$(date +%Y%m%d-%H%M%S)
    mkdir -p "$LOG_DIR"
    for f in dnstt.log server.log monitor.log update.log; do
        if [[ -s "$LOG_DIR/$f" ]]; then
            mv "$LOG_DIR/$f" "$LOG_DIR/${f%.log}-$ts.log"
        fi
        : > "$LOG_DIR/$f"
    done
    find "$LOG_DIR" -type f -name "*-*.log" -mtime +14 -delete 2>/dev/null || true
    log_success "Логи очищены"
    
    log_info "Запускаем сервис..."
    systemctl start $SERVICE_NAME 2>/dev/null || true
    if systemctl is-active --quiet $SERVICE_NAME; then
        log_success "Сервис запущен"
    else
        log_warning "Сервис не запустился, проверьте: qdynn logs"
    fi
}

# Настройка сервера
configure_server() {
    local param=$1
    local value=$2
    
    show_banner
    
    case "$param" in
        "domain")
            if [[ -z "$value" ]]; then
                log_error "Использование: qdynn config domain example.com"
                return 1
            fi
            set_domain "$value"
            ;;
        "ssl")
            setup_ssl_certificate
            ;;
        "setup")
            initial_setup
            ;;
        "edit")
            ${EDITOR:-nano} $CONFIG_DIR/server.conf
            ;;
        *)
            echo -e "${YELLOW}Доступные настройки:${NC}"
            echo -e "  ${CYAN}qdynn config domain <домен>${NC}     - установить домен"
            echo -e "  ${CYAN}qdynn config ssl${NC}                - настроить SSL сертификат"
            echo -e "  ${CYAN}qdynn config setup${NC}              - первичная настройка"
            echo -e "  ${CYAN}qdynn config edit${NC}               - редактировать конфигурацию"
            ;;
    esac
}

# Установка домена
set_domain() {
    local domain=$1
    
    log_info "Устанавливаем домен: $domain"
    
    # Обновляем конфигурацию
    sed -i "s/SERVER_DOMAIN=.*/SERVER_DOMAIN=\"$domain\"/" $CONFIG_DIR/server.conf
    
    log_success "Домен установлен: $domain"
    log_info "Не забудьте создать DNS записи:";
    echo -e "  ${YELLOW}ns.$domain${NC}    A     $(curl -s ifconfig.me)"
    echo -e "  ${YELLOW}$domain${NC}       NS    ns.$domain"
}

# Управление клиентами
manage_clients() {
    local action=$1
    local client_name=$2
    
    show_banner
    
    case "$action" in
        "list")
            list_clients
            ;;
        "add")
            add_client "$client_name"
            ;;
        "remove")
            remove_client "$client_name"
            ;;
        *)
            echo -e "${YELLOW}Управление клиентами:${NC}"
            echo -e "  ${CYAN}qdynn clients list${NC}           - список клиентов"
            echo -e "  ${CYAN}qdynn clients add <имя>${NC}      - добавить клиента"
            echo -e "  ${CYAN}qdynn clients remove <имя>${NC}   - удалить клиента"
            ;;
    esac
}

# Получить количество клиентов
get_client_count() {
    if [[ -f "$LOG_DIR/clients.log" ]]; then
        wc -l < "$LOG_DIR/clients.log" 2>/dev/null || echo "0"
    else
        echo "0"
    fi
}

# Обновление сервера
update_server() {
    show_banner
    log_info "Проверяем обновления..."
    
    # Скачиваем и запускаем обновленный установщик
    curl -fsSL https://raw.githubusercontent.com/Stepan163s/qdynn-server/main/update.sh | bash
}

# Помощь
show_help() {
    show_banner
    
    echo -e "${WHITE}Использование:${NC} qdynn <команда> [параметры]\n"
    
    echo -e "${CYAN}🚀 УПРАВЛЕНИЕ СЕРВЕРОМ:${NC}"
    echo -e "  ${GREEN}start${NC}                    Запустить сервер"
    echo -e "  ${GREEN}stop${NC}                     Остановить сервер" 
    echo -e "  ${GREEN}restart${NC}                  Перезапустить сервер"
    echo -e "  ${GREEN}status${NC}                   Показать статус и данные подключения"
    echo -e ""
    
    echo -e "${CYAN}📊 МОНИТОРИНГ:${NC}"
    echo -e "  ${GREEN}logs${NC} [количество]        Показать логи (по умолчанию: 50 строк)"
    echo -e "  ${GREEN}logs clear${NC}              Очистить текущие логи с ротацией"
    echo -e ""
    
    echo -e "${CYAN}⚙️ НАСТРОЙКА:${NC}"
    echo -e "  ${GREEN}config${NC} domain <домен>    Установить домен сервера"
    echo -e "  ${GREEN}config${NC} ssl               Настроить SSL сертификат"
    echo -e "  ${GREEN}config${NC} setup             Первичная настройка"
    echo -e "  ${GREEN}config${NC} edit              Редактировать конфигурацию"
    echo -e ""
    
    echo -e "${CYAN}👥 КЛИЕНТЫ:${NC}"
    echo -e "  ${GREEN}clients${NC} list             Список подключенных клиентов"
    echo -e "  ${GREEN}clients${NC} add <имя>        Добавить клиента"
    echo -e "  ${GREEN}clients${NC} remove <имя>     Удалить клиента"
    echo -e ""
    
    echo -e "${CYAN}🔄 ОБНОВЛЕНИЕ:${NC}"
    echo -e "  ${GREEN}update${NC}                   Обновить до последней версии"
    echo -e ""
    
    echo -e "${BLUE}📚 Документация:${NC} https://github.com/Stepan163s/qdynn-server"
    echo -e "${BLUE}💬 Поддержка:${NC}    https://t.me/qdynn_support"
    echo -e ""
}

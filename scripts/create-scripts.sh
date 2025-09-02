#!/bin/bash
# Создание дополнительных скриптов для QDYNN-SERVER

INSTALL_DIR="/opt/qdynn-server"
CONFIG_DIR="/etc/qdynn"
LOG_DIR="/var/log/qdynn"

# Скрипт запуска DNSTT сервера
cat > $INSTALL_DIR/scripts/start-server.sh << 'EOF'
#!/bin/bash
# QDYNN-SERVER Start Script

INSTALL_DIR="/opt/qdynn-server"
CONFIG_DIR="/etc/qdynn"
LOG_DIR="/var/log/qdynn"
PID_FILE="$INSTALL_DIR/run/qdynn-server.pid"

# Загружаем конфигурацию
source $CONFIG_DIR/server.conf

# Функция логирования
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] $1" >> $LOG_DIR/server.log
}

log "Запускаем QDYNN DNSTT Server..."
log "Домен: $SERVER_DOMAIN, IP: $EXTERNAL_IP"

# Создаем директории если не существуют
mkdir -p $LOG_DIR/clients
mkdir -p $INSTALL_DIR/run

# Запускаем DNSTT сервер
cd $INSTALL_DIR
exec $INSTALL_DIR/bin/dnstt-server \
    -domain "ns.$SERVER_DOMAIN" \
    -privkey-file <(echo -n "$PRIVATE_KEY" | xxd -r -p) \
    -mtu 1280 \
    -max-clients $MAX_CLIENTS \
    >> $LOG_DIR/dnstt.log 2>&1 &

# Сохраняем PID
echo $! > $PID_FILE
log "DNSTT Server запущен с PID: $(cat $PID_FILE)"

# Мониторинг процесса
while kill -0 $(cat $PID_FILE) 2>/dev/null; do
    sleep 60
    # Ротация логов если файл больше 100MB
    if [[ $(stat -c%s "$LOG_DIR/dnstt.log" 2>/dev/null || echo 0) -gt 104857600 ]]; then
        mv $LOG_DIR/dnstt.log $LOG_DIR/dnstt.log.old
        log "Ротация логов выполнена"
    fi
done

log "DNSTT Server процесс завершен"
EOF

# Скрипт остановки
cat > $INSTALL_DIR/scripts/stop-server.sh << 'EOF'
#!/bin/bash
# QDYNN-SERVER Stop Script

LOG_DIR="/var/log/qdynn"
PID_FILE="/opt/qdynn-server/run/qdynn-server.pid"

# Функция логирования
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] $1" >> $LOG_DIR/server.log
}

if [[ -f $PID_FILE ]]; then
    PID=$(cat $PID_FILE)
    if kill -0 $PID 2>/dev/null; then
        log "Останавливаем DNSTT Server (PID: $PID)..."
        kill -TERM $PID
        
        # Ждем до 30 секунд для graceful shutdown
        for i in {1..30}; do
            if ! kill -0 $PID 2>/dev/null; then
                log "DNSTT Server остановлен"
                rm -f $PID_FILE
                exit 0
            fi
            sleep 1
        done
        
        # Принудительное завершение
        log "Принудительная остановка DNSTT Server..."
        kill -KILL $PID 2>/dev/null
        rm -f $PID_FILE
    else
        log "PID файл найден, но процесс не активен"
        rm -f $PID_FILE
    fi
else
    log "PID файл не найден"
fi
EOF

# Скрипт мониторинга
cat > $INSTALL_DIR/scripts/monitor.sh << 'EOF'
#!/bin/bash
# QDYNN-SERVER Monitor Script

INSTALL_DIR="/opt/qdynn-server"
CONFIG_DIR="/etc/qdynn"
LOG_DIR="/var/log/qdynn"

# Загружаем конфигурацию
source $CONFIG_DIR/server.conf

# Функция логирования
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [MONITOR] $1" >> $LOG_DIR/monitor.log
}

# Проверка работы DNSTT сервера
check_dnstt() {
    if pgrep -f "dnstt-server" > /dev/null; then
        return 0
    else
        return 1
    fi
}

# Проверка DNS резолвинга
check_dns() {
    nslookup "test.ns.$SERVER_DOMAIN" 127.0.0.1 > /dev/null 2>&1
    return $?
}

# Статистика клиентов
log_client_stats() {
    CLIENT_COUNT=$(ss -tuln | grep ":53 " | wc -l)
    echo "$(date '+%Y-%m-%d %H:%M:%S') Активных клиентов: $CLIENT_COUNT" >> $LOG_DIR/clients.log
}

# Основной цикл мониторинга
log "Запуск мониторинга QDYNN Server"
while true; do
    if check_dnstt; then
        log_client_stats
    else
        log "КРИТИЧНО: DNSTT сервер не отвечает!"
        # Можно добавить уведомления или автоперезапуск
    fi
    
    sleep 300  # Проверка каждые 5 минут
done
EOF

# Скрипт обновления
cat > $INSTALL_DIR/scripts/update.sh << 'EOF'
#!/bin/bash
# QDYNN-SERVER Update Script

REPO_URL="https://api.github.com/repos/Stepan163s/qdynn-server/releases/latest"
INSTALL_DIR="/opt/qdynn-server"
LOG_DIR="/var/log/qdynn"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [UPDATE] $1" >> $LOG_DIR/update.log
}

log "Проверяем обновления..."

# Получаем информацию о последней версии
LATEST_VERSION=$(curl -s $REPO_URL | jq -r '.tag_name' 2>/dev/null || echo "unknown")
CURRENT_VERSION=$(cat $INSTALL_DIR/VERSION 2>/dev/null || echo "1.0.0")

if [[ "$LATEST_VERSION" != "$CURRENT_VERSION" ]] && [[ "$LATEST_VERSION" != "unknown" ]]; then
    log "Доступна новая версия: $LATEST_VERSION (текущая: $CURRENT_VERSION)"
    
    # Скачиваем и запускаем скрипт обновления
    curl -fsSL https://raw.githubusercontent.com/Stepan163s/qdynn-server/main/update.sh | bash
else
    log "Обновлений не найдено (версия: $CURRENT_VERSION)"
fi
EOF

# Устанавливаем права на выполнение
chmod +x $INSTALL_DIR/scripts/*.sh

echo "Скрипты созданы успешно!"

#!/bin/bash
# QDYNN-SERVER Demo Script
# Демонстрация возможностей системы

set -e

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

echo -e "\n${PURPLE}▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓${NC}"
echo -e "${WHITE}      🚀 QDYNN-SERVER v1.0.0 - ДЕМОНСТРАЦИЯ${NC}"
echo -e "${PURPLE}▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓${NC}\n"

echo -e "${CYAN}🎯 Что делает QDYNN-SERVER:${NC}"
echo -e "• ${GREEN}Автоматическая установка${NC} DNSTT туннель-сервера одной командой"
echo -e "• ${GREEN}Красивый CLI интерфейс${NC} для управления"
echo -e "• ${GREEN}Генерация QR-кодов${NC} для мобильных клиентов"
echo -e "• ${GREEN}Мониторинг и логирование${NC} в реальном времени"
echo -e "• ${GREEN}Автоматические обновления${NC} и резервное копирование"
echo -e ""

echo -e "${YELLOW}📋 Файлы проекта:${NC}"
find . -type f -name "*.sh" -o -name "*.md" -o -name "*.conf*" -o -name "Makefile" | sort | while read file; do
    echo -e "  ${BLUE}$file${NC}"
done
echo -e ""

echo -e "${GREEN}🔧 Тестирование синтаксиса скриптов:${NC}"

# Проверка синтаксиса
scripts=(
    "./install.sh"
    "./update.sh" 
    "./scripts/cli-functions.sh"
    "./scripts/create-scripts.sh"
)

for script in "${scripts[@]}"; do
    if [[ -f "$script" ]]; then
        if bash -n "$script"; then
            echo -e "  ✅ ${script} - синтаксис OK"
        else
            echo -e "  ❌ ${script} - синтаксис ERROR"
        fi
    fi
done

echo -e "\n${CYAN}📦 Готовые команды для пользователя:${NC}"
echo -e ""
echo -e "${WHITE}# Автоматическая установка одной командой:${NC}"
echo -e "${YELLOW}curl -fsSL https://raw.githubusercontent.com/Stepan163s/qdynn-server/main/install.sh | sudo bash${NC}"
echo -e ""
echo -e "${WHITE}# Управление сервером:${NC}"
echo -e "${YELLOW}sudo qdynn start${NC}     # Запуск"
echo -e "${YELLOW}qdynn status${NC}         # Статус и данные подключения"  
echo -e "${YELLOW}qdynn logs${NC}           # Просмотр логов"
echo -e "${YELLOW}qdynn config domain tunnel.example.com${NC}  # Настройка домена"
echo -e ""

echo -e "${BLUE}🌐 GitHub Repository:${NC}"
echo -e "https://github.com/Stepan163s/qdynn-server"
echo -e ""

echo -e "${GREEN}📱 Интеграция с мобильным приложением:${NC}"
echo -e "После запуска сервер покажет QR-код и данные для настройки Android приложения QDYNN"
echo -e ""

echo -e "${WHITE}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${WHITE}║                   ПРОЕКТ ГОТОВ К РЕЛИЗУ!                  ║${NC}"
echo -e "${WHITE}╚═══════════════════════════════════════════════════════════╝${NC}"

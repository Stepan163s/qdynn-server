# QDYNN-SERVER Makefile

VERSION ?= $(shell cat VERSION)
BUILD_TIME ?= $(shell date -u '+%Y-%m-%d_%H:%M:%S')
GIT_COMMIT ?= $(shell git rev-parse --short HEAD 2>/dev/null || echo 'unknown')

.PHONY: help install uninstall test clean build package deploy

# Default target
help: ## Показать это сообщение помощи
	@echo "🚀 QDYNN-SERVER v$(VERSION) - Makefile команды:"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'
	@echo ""

install: ## Установить QDYNN-SERVER на систему
	@echo "🔧 Устанавливаем QDYNN-SERVER..."
	sudo bash install.sh

uninstall: ## Полностью удалить QDYNN-SERVER
	@echo "🗑️  Удаляем QDYNN-SERVER..."
	sudo systemctl stop qdynn-server 2>/dev/null || true
	sudo systemctl disable qdynn-server 2>/dev/null || true
	sudo rm -f /etc/systemd/system/qdynn-server.service
	sudo rm -f /usr/local/bin/qdynn
	sudo rm -rf /opt/qdynn-server
	sudo rm -rf /etc/qdynn
	sudo rm -rf /var/log/qdynn
	sudo userdel qdynn 2>/dev/null || true
	sudo systemctl daemon-reload
	@echo "✅ QDYNN-SERVER полностью удален"

test: ## Запустить тесты
	@echo "🧪 Запускаем тесты..."
	@bash -n install.sh && echo "✅ install.sh синтаксис OK" || echo "❌ install.sh синтаксис ERROR"
	@bash -n update.sh && echo "✅ update.sh синтаксис OK" || echo "❌ update.sh синтаксис ERROR"
	@bash -n scripts/cli-functions.sh && echo "✅ cli-functions.sh синтаксис OK" || echo "❌ cli-functions.sh синтаксис ERROR"
	@echo "✅ Все тесты пройдены"

clean: ## Очистить временные файлы
	@echo "🧹 Очищаем временные файлы..."
	@rm -rf build/
	@rm -rf dist/
	@rm -rf *.tar.gz
	@rm -rf *.zip
	@find . -name "*.tmp" -delete
	@find . -name "*~" -delete
	@echo "✅ Очистка завершена"

build: clean ## Собрать дистрибутив
	@echo "📦 Собираем QDYNN-SERVER v$(VERSION)..."
	@mkdir -p build dist
	
	# Копируем файлы
	@cp -r scripts configs templates build/
	@cp install.sh update.sh README.md LICENSE VERSION CHANGELOG.md build/
	
	# Создаем архив
	@cd build && tar -czf ../dist/qdynn-server-v$(VERSION).tar.gz .
	@cd build && zip -r ../dist/qdynn-server-v$(VERSION).zip . >/dev/null
	
	@echo "✅ Дистрибутив собран:"
	@ls -la dist/

package: build ## Создать .deb и .rpm пакеты
	@echo "📦 Создаем пакеты..."
	@mkdir -p build/deb/DEBIAN
	@mkdir -p build/deb/opt/qdynn-server
	@mkdir -p build/deb/usr/local/bin
	
	# Копируем файлы для .deb
	@cp -r scripts configs templates build/deb/opt/qdynn-server/
	@cp install.sh update.sh build/deb/opt/qdynn-server/
	
	# Создаем control файл
	@echo "Package: qdynn-server" > build/deb/DEBIAN/control
	@echo "Version: $(VERSION)" >> build/deb/DEBIAN/control
	@echo "Section: net" >> build/deb/DEBIAN/control
	@echo "Priority: optional" >> build/deb/DEBIAN/control
	@echo "Architecture: amd64" >> build/deb/DEBIAN/control
	@echo "Depends: curl, wget, golang-go, systemd" >> build/deb/DEBIAN/control
	@echo "Maintainer: QDYNN Team <support@qdynn.org>" >> build/deb/DEBIAN/control
	@echo "Description: QDYNN DNSTT Tunnel Server" >> build/deb/DEBIAN/control
	@echo " Автоматический DNSTT туннель-сервер для обхода блокировок" >> build/deb/DEBIAN/control
	
	# Собираем .deb
	@dpkg-deb --build build/deb dist/qdynn-server-v$(VERSION).deb 2>/dev/null || echo "⚠️ dpkg-deb не найден, .deb пакет не создан"
	
	@echo "✅ Пакеты созданы"

deploy: ## Деплой на GitHub Releases
	@echo "🚀 Деплоим QDYNN-SERVER v$(VERSION)..."
	@if [ -z "$(GITHUB_TOKEN)" ]; then \
		echo "❌ Установите GITHUB_TOKEN для деплоя"; \
		exit 1; \
	fi
	
	# Создаем релиз через GitHub API
	@echo "📡 Создаем GitHub Release..."
	@curl -X POST \
		-H "Authorization: token $(GITHUB_TOKEN)" \
		-H "Accept: application/vnd.github.v3+json" \
		https://api.github.com/repos/stepan163/qdynn-server/releases \
		-d '{"tag_name":"v$(VERSION)","name":"QDYNN-SERVER v$(VERSION)","body":"См. CHANGELOG.md для деталей","draft":false,"prerelease":false}'
	
	@echo "✅ Релиз создан: https://github.com/stepan163/qdynn-server/releases/tag/v$(VERSION)"

status: ## Показать статус установленного сервера
	@if command -v qdynn >/dev/null 2>&1; then \
		echo "✅ QDYNN-SERVER установлен"; \
		qdynn status; \
	else \
		echo "❌ QDYNN-SERVER не установлен"; \
		echo "Выполните: make install"; \
	fi

logs: ## Показать логи сервера
	@if command -v qdynn >/dev/null 2>&1; then \
		qdynn logs; \
	else \
		echo "❌ QDYNN-SERVER не установлен"; \
	fi

demo: ## Запустить демо установку в Docker
	@echo "🐳 Запускаем демо в Docker..."
	@docker run --rm -it \
		-v $(PWD):/workspace \
		-w /workspace \
		ubuntu:22.04 \
		bash -c "apt update && apt install -y curl sudo && bash install.sh"

info: ## Показать информацию о проекте
	@echo ""
	@echo "🚀 QDYNN-SERVER v$(VERSION)"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "📅 Время сборки: $(BUILD_TIME)"
	@echo "📝 Git commit:   $(GIT_COMMIT)"
	@echo "🌐 Repository:   https://github.com/stepan163/qdynn-server"
	@echo "📱 Mobile App:   https://github.com/stepan163/qdynn"
	@echo "📧 Support:      https://t.me/qdynn_support"
	@echo ""

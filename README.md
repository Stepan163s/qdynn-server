# 🚀 QDYNN-SERVER
**Автоматический DNSTT туннель-сервер для обхода блокировок**


**ЯДРО СИСТЕМЫ:** Использует [DNSTT Server от David Fifield](https://www.bamsoftware.com/git/dnstt.git)  
**НАША РОЛЬ:** Создание удобной автоматической обертки для развертывания и управления


## ⚡ Быстрый старт
```bash
# Автоматическая установка одной командой
curl -fsSL https://raw.githubusercontent.com/Stepan163s/qdynn-server/main/install.sh | sudo bash

# Запуск сервера
sudo qdynn start

# Получить данные для подключения
qdynn status
```

### 🔍 Установка в режиме отладки (debug)
Чтобы увидеть подробный вывод и понять, на каком шаге установка может завершаться с ошибкой, используйте debug-режим:

```bash
# Через флаг --debug
curl -fsSL https://raw.githubusercontent.com/Stepan163s/qdynn-server/main/install.sh \
  | sudo bash -s -- --debug 2>&1 | tee ~/qdynn-install-debug.log

# Или через переменную окружения
curl -fsSL https://raw.githubusercontent.com/Stepan163s/qdynn-server/main/install.sh \
  | sudo QDYNN_DEBUG=1 bash -s -- 2>&1 | tee ~/qdynn-install-debug.log
```

В debug-режиме включается трассировка команд, ошибок и отключается подавление вывода у `apt-get`, `git clone`, `go build`, `systemctl`. Это помогает быстро найти точную причину сбоя.

## 🎯 Возможности
- ✅ **Автоматическая установка** всех зависимостей
- ✅ **CLI интерфейс** с цветным выводом
- ✅ **Автоматическая настройка** DNS и SSL сертификатов  
- ✅ **Мониторинг** состояния туннеля
- ✅ **Генерация** конфигураций для клиентов
- ✅ **Логирование** и диагностика

## 🛠️ Команды
```bash
qdynn start           # Запустить сервер
qdynn stop            # Остановить сервер
qdynn restart         # Перезапустить сервер
qdynn status          # Состояние и данные подключения
qdynn logs            # Просмотр логов
qdynn logs clear      # Очистить текущие логи с ротацией
qdynn config          # Настройка параметров
qdynn clients         # Управление клиентами
qdynn update          # Обновление до последней версии
```

## 📱 Интеграция с мобильным приложением
После запуска сервер покажет QR-код и данные для настройки мобильного приложения QDYNN.


## 🔧 Требования
- **Ubuntu 20.04+** или **Debian 11+**
- **Root доступ** для установки  
- **Домен** с DNS записями (опционально)

---

## 🧭 Настройка DNS

Для работы DNS-туннеля нужен NS-домен, который указывает на ваш сервер.

Пример (обезличенный) для зоны `tunnel.example.com`:

1) A-запись для NS-узла:

    ns.tunnel.example.com → YOUR_SERVER_IP

2) NS-запись для сабдомена-зоны:

    tunnel.example.com → ns.tunnel.example.com

Подсказка в CLI:
```bash
qdynn config domain tunnel.example.com
# В выводе появятся необходимые записи A и NS с вашим внешним IP
```

Проверка DNS после настройки:
```bash
nslookup ns.tunnel.example.com
dig NS tunnel.example.com +short
```

После применения DNS-записей может понадобиться время на распространение (обычно до 15 минут, иногда до 24 часов).

---

## 🔗 **Ссылки**

**Наш проект:**
- **🔗 GitHub:** https://github.com/stepan163s/qdynn-server  
- **📱 Mobile App:** https://github.com/stepan163s/qdynn



# production-template

Минимальный production-шаблон для запуска сервисов сбора данных на Linux через systemd. Включает самовосстановление, проверку свежести данных, ротацию по возрасту и автоматический бэкап.

Сделан для solo-операторов: система работает без присмотра.

## Что внутри

| Компонент | Задача | Расписание |
|-----------|--------|------------|
| `watchdog.sh` | Мониторит systemd-сервисы, перезапускает упавшие | каждые 5 мин |
| `healthcheck.sh` | Проверяет свежесть данных (возраст файла vs максимум) | каждый час |
| `rotate.sh` | Старые файлы → архив → gzip → cold storage | ежедневно 06:00 |
| `backup.sh` | Sync кода и данных в S3 через rclone | ежедневно 04:00 |

Все скрипты конфиг-ориентированы. Правишь `.list` в `config/` — код не трогаешь.

## Архитектура

┌─────────────────────────────────────────────────────┐
│ systemd timers │
│ watchdog.timer → watchdog.service │
│ healthcheck.timer → healthcheck.service │
│ rotate.timer → rotate.service │
│ backup.timer → backup.service │
└──────────────────┬──────────────────────────────────┘
│
┌───────────┼───────────┬──────────────┐
▼ ▼ ▼ ▼
watchdog.sh healthcheck rotate.sh backup.sh
│ .sh │ │
▼ ▼ ▼ ▼
systemctl file age age-based rclone
is-active vs max tiering sync → S3

## Быстрый старт

```bash
# 1. Скопировать в целевую папку
sudo cp -r production-template /opt/production-template
cd /opt/production-template

# 2. Отредактировать конфиги
nano config/services.list       # сервисы для мониторинга
nano config/healthcheck.list    # данные + макс. возраст
nano config/rotate.list         # уровни ротации
nano config/backup.list         # rclone: источники → назначения

# 3. Установить systemd-юниты
sudo cp systemd/*.service /etc/systemd/system/
sudo cp systemd/*.timer   /etc/systemd/system/
sudo systemctl daemon-reload

# 4. Включить таймеры
sudo systemctl enable --now watchdog.timer
sudo systemctl enable --now healthcheck.timer
sudo systemctl enable --now rotate.timer
sudo systemctl enable --now backup.timer

# 5. Проверить
systemctl list-timers 'watchdog*' 'healthcheck*' 'rotate*' 'backup*'

Формат конфигов

config/services.list — один systemd-сервис на строку:
myapp-collector.service
myapp-aggregator.service

config/healthcheck.list — <путь>|<макс_возраст_ч>|<имя>:
/data/raw/quotes/latest.csv|2|quotes_latest
/data/raw/trades/latest.csv|24|trades_daily

config/rotate.list — <путь>|<live_дней>|<archive_дней>|<cold_дней>:
/data/raw/trades|30|90|365

config/backup.list — <источник>|<rclone_назначение>:
/home/user/project/scripts|s3:my-backup/scripts
/data/raw/algopack|s3:my-backup/data/algopack

Принципы дизайна

1.Oneshot-сервисы + таймеры, не долгоживущие демоны. Проще, надёжнее.

2.Конфиг-ориентированность. Новый чек = одна строка в .list.

3.Ротация логов встроена. Каждый скрипт чистит свой лог на 5–10 МБ.

4.Секретов в коде нет. Всё через переменные окружения.

Логи

Лог     	Расположение
watchdog	/var/log/watchdog.log
healthcheck	/var/log/healthcheck.log
rotate  	/var/log/rotate.log
backup  	/var/log/backup.log

Переопределяются через environment в .service файлах.

Требования

1.Linux с systemd (Ubuntu 22.04+, Debian 12+ и т.д.)

2.bash 4+

3.rclone (для бэкапа) — установлен и настроен отдельно

4.gzip (для ротации)

Чего этот шаблон НЕ делает

1.Не управляет самим сбором данных (свои сервисы).

2.Не работает с секретами. Используй env-файлы или secret manager.

3.Не включает UI мониторинга. Парься с Prometheus/Grafana если нужно.

Лицензия

MIT

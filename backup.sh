#!/bin/bash

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Конфигурация
BACKUP_DIR="$HOME/backups"
PROJECT_DIR="$HOME/lepp"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="lepp_backup_$DATE"
BACKUP_PATH="$BACKUP_DIR/$BACKUP_NAME"
LOG_FILE="$BACKUP_DIR/backup.log"

# Настройки Docker
DB_CONTAINER="lepp-db"
POSTGRES_USER="leppuser"
POSTGRES_DB="leppdb"

# Retention (дни хранения)
RETENTION_DAYS=7

# Функция логирования
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

# Проверка, что контейнеры запущены
check_containers() {
    log "Проверка статуса контейнеров..."
    
    if ! docker ps | grep -q "$DB_CONTAINER"; then
        error "Контейнер $DB_CONTAINER не запущен!"
        return 1
    fi
    
    success "Все контейнеры работают"
    return 0
}

# Создание директории бэкапа
create_backup_dir() {
    log "Создание директории бэкапа: $BACKUP_PATH"
    
    if ! mkdir -p "$BACKUP_PATH"; then
        error "Не удалось создать директорию $BACKUP_PATH"
        return 1
    fi
    
    success "Директория создана"
    return 0
}

# Бэкап PostgreSQL
backup_database() {
    log "Начало бэкапа базы данных PostgreSQL..."
    
    local db_backup_file="$BACKUP_PATH/database.sql"
    
    if docker exec "$DB_CONTAINER" pg_dump -U "$POSTGRES_USER" "$POSTGRES_DB" > "$db_backup_file" 2>> "$LOG_FILE"; then
        local db_size=$(du -h "$db_backup_file" | cut -f1)
        success "База данных сохранена: $db_backup_file ($db_size)"
        return 0
    else
        error "Ошибка при бэкапе базы данных"
        return 1
    fi
}

# Бэкап volumes Docker
backup_volumes() {
    log "Начало бэкапа Docker volumes..."
    
    local volumes_dir="$BACKUP_PATH/volumes"
    mkdir -p "$volumes_dir"
    
    # Список volumes для бэкапа
    local volumes=("db_data" "redis_data" "grafana_data" "prometheus_data")
    
    for volume in "${volumes[@]}"; do
        local full_volume_name="lepp-docker_${volume}"
        local volume_backup="$volumes_dir/${volume}.tar.gz"
        
        log "Бэкап volume: $full_volume_name"
        
        if docker run --rm -v "$full_volume_name:/volume" -v "$volumes_dir:/backup" alpine \
            tar czf "/backup/${volume}.tar.gz" -C /volume . 2>> "$LOG_FILE"; then
            local vol_size=$(du -h "$volume_backup" | cut -f1)
            success "Volume $volume сохранен ($vol_size)"
        else
            warning "Не удалось сохранить volume $volume (возможно не существует)"
        fi
    done
    
    return 0
}

# Бэкап конфигурационных файлов
backup_configs() {
    log "Начало бэкапа конфигурационных файлов..."
    
    local configs_backup="$BACKUP_PATH/configs.tar.gz"
    
    cd "$PROJECT_DIR" || return 1
    
    if tar czf "$configs_backup" \
        docker-compose.yml \
        .env \
        reverse-proxy/ \
        app/ \
        db/ \
        prometheus/ \
        loki/ \
        promtail/ \
        grafana/ \
        2>> "$LOG_FILE"; then
        local cfg_size=$(du -h "$configs_backup" | cut -f1)
        success "Конфигурации сохранены ($cfg_size)"
        return 0
    else
        error "Ошибка при бэкапе конфигураций"
        return 1
    fi
}

# Бэкап файлов приложения
backup_www() {
    log "Начало бэкапа файлов приложения..."
    
    local www_backup="$BACKUP_PATH/www.tar.gz"
    
    if tar czf "$www_backup" -C "$PROJECT_DIR" www 2>> "$LOG_FILE"; then
        local www_size=$(du -h "$www_backup" | cut -f1)
        success "Файлы приложения сохранены ($www_size)"
        return 0
    else
        error "Ошибка при бэкапе файлов приложения"
        return 1
    fi
}

# Создание метаданных бэкапа
create_metadata() {
    log "Создание метаданных бэкапа..."
    
    local metadata_file="$BACKUP_PATH/metadata.txt"
    
    cat > "$metadata_file" << METADATA
Backup Information
==================
Date: $(date '+%Y-%m-%d %H:%M:%S')
Hostname: $(hostname)
User: $(whoami)
Project: LEPP Stack
Database: $POSTGRES_DB

Containers Status:
$(docker ps --filter "name=lepp-" --format "table {{.Names}}\t{{.Status}}")

Total Backup Size: $(du -sh "$BACKUP_PATH" | cut -f1)
METADATA
    
    success "Метаданные созданы"
    return 0
}

# Создание финального архива
create_final_archive() {
    log "Создание финального архива..."
    
    local final_archive="$BACKUP_DIR/${BACKUP_NAME}.tar.gz"
    
    if tar czf "$final_archive" -C "$BACKUP_DIR" "$BACKUP_NAME" 2>> "$LOG_FILE"; then
        local final_size=$(du -h "$final_archive" | cut -f1)
        success "Финальный архив создан: $final_archive ($final_size)"
        
        # Удаление временной директории
        rm -rf "$BACKUP_PATH"
        
        return 0
    else
        error "Ошибка при создании финального архива"
        return 1
    fi
}

# Очистка старых бэкапов
cleanup_old_backups() {
    log "Очистка бэкапов старше $RETENTION_DAYS дней..."
    
    local deleted_count=0
    while IFS= read -r old_backup; do
        log "Удаление: $old_backup"
        rm -f "$old_backup"
        ((deleted_count++))
    done < <(find "$BACKUP_DIR" -name "lepp_backup_*.tar.gz" -type f -mtime +$RETENTION_DAYS)
    
    if [ $deleted_count -gt 0 ]; then
        success "Удалено старых бэкапов: $deleted_count"
    else
        log "Старых бэкапов для удаления не найдено"
    fi
    
    return 0
}

# Основная функция
main() {
    echo "=================================="
    echo "  LEPP Stack Backup Script"
    echo "=================================="
    echo ""
    
    log "Начало процесса бэкапа"
    
    # Проверки
    if ! check_containers; then
        error "Бэкап прерван: контейнеры не готовы"
        exit 1
    fi
    
    # Создание структуры
    create_backup_dir || exit 1
    
    # Выполнение бэкапов
    local backup_failed=0
    
    backup_database || ((backup_failed++))
    backup_volumes || ((backup_failed++))
    backup_configs || ((backup_failed++))
    backup_www || ((backup_failed++))
    create_metadata
    
    if [ $backup_failed -gt 0 ]; then
        warning "Некоторые компоненты не были сохранены ($backup_failed ошибок)"
    fi
    
    # Финализация
    create_final_archive || exit 1
    cleanup_old_backups
    
    echo ""
    success "=== Бэкап успешно завершен ==="
    log "Бэкап завершен: $BACKUP_DIR/${BACKUP_NAME}.tar.gz"
    
    # Показать список бэкапов
    echo ""
    echo "Доступные бэкапы:"
    ls -lh "$BACKUP_DIR"/lepp_backup_*.tar.gz 2>/dev/null | tail -5
}

# Запуск
main "$@"

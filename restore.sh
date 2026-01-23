#!/bin/bash

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Конфигурация
BACKUP_DIR="$HOME/backups"
PROJECT_DIR="$HOME/lepp"
LOG_FILE="$BACKUP_DIR/restore.log"

# Настройки Docker
DB_CONTAINER="lepp-db"
POSTGRES_USER="leppuser"
POSTGRES_DB="leppdb"

# Функции вывода
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

info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

# Показать доступные бэкапы
list_backups() {
    echo "Доступные бэкапы:"
    echo "================="
    
    local backups=($(ls -t "$BACKUP_DIR"/lepp_backup_*.tar.gz 2>/dev/null))
    
    if [ ${#backups[@]} -eq 0 ]; then
        error "Бэкапы не найдены в $BACKUP_DIR"
        return 1
    fi
    
    local i=1
    for backup in "${backups[@]}"; do
        local size=$(du -h "$backup" | cut -f1)
        echo "  [$i] $(basename "$backup") - $size"
        ((i++))
    done
    
    echo ""
    return 0
}

# Выбор бэкапа
select_backup() {
    list_backups || return 1
    
    local backups=($(ls -t "$BACKUP_DIR"/lepp_backup_*.tar.gz))
    local backup_count=${#backups[@]}
    
    echo -n "Введите номер бэкапа [1-$backup_count]: "
    read selection
    
    if [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -ge 1 ] && [ "$selection" -le "$backup_count" ]; then
        SELECTED_BACKUP="${backups[$((selection-1))]}"
    else
        error "Неверный выбор"
        return 1
    fi
    
    info "Выбран бэкап: $(basename "$SELECTED_BACKUP")"
    return 0
}

# Подтверждение
confirm_restore() {
    warning "ВНИМАНИЕ! Восстановление перезапишет текущие данные!"
    echo -n "Продолжить? (yes/no): "
    read confirmation
    
    if [ "$confirmation" != "yes" ]; then
        log "Восстановление отменено"
        return 1
    fi
    
    return 0
}

# Остановка контейнеров — УМНАЯ ВЕРСИЯ
stop_containers() {
    log "Проверка состояния контейнеров..."
    
    cd "$PROJECT_DIR" || return 1

    # Если docker-compose.yml отсутствует — нет смысла проверять контейнеры
    if [ ! -f "docker-compose.yml" ]; then
        info "docker-compose.yml отсутствует — пропускаем остановку"
        return 0
    fi

    # Проверяем, есть ли запущенные контейнеры
    if docker compose ps --services --status running 2>/dev/null | grep -q .; then
        log "Обнаружены запущенные контейнеры. Остановка..."
        if docker compose down 2>> "$LOG_FILE"; then
            success "Контейнеры успешно остановлены"
            return 0
        else
            error "Не удалось остановить контейнеры"
            return 1
        fi
    else
        info "Контейнеры не запущены — остановка не требуется"
        return 0
    fi
}

# Извлечение бэкапа
extract_backup() {
    log "Извлечение бэкапа..."
    
    local temp_dir="$BACKUP_DIR/restore_temp_$$"
    mkdir -p "$temp_dir"
    
    if ! tar xzf "$SELECTED_BACKUP" -C "$temp_dir" 2>> "$LOG_FILE"; then
        error "Ошибка извлечения"
        rm -rf "$temp_dir" 2>/dev/null
        return 1
    fi

    local -a contents
    while IFS= read -r -d '' item; do
        contents+=("$item")
    done < <(find "$temp_dir" -mindepth 1 -maxdepth 1 -print0)

    if [ "${#contents[@]}" -ne 1 ]; then
        error "Ожидалась одна папка в архиве, но найдено ${#contents[@]}"
        rm -rf "$temp_dir" 2>/dev/null
        return 1
    fi

    RESTORE_DIR="${contents[0]}"
    success "Бэкап извлечен"
    
    if [ -f "$RESTORE_DIR/metadata.txt" ]; then
        echo ""
        cat "$RESTORE_DIR/metadata.txt"
        echo ""
    fi
    
    return 0
}

# Восстановление конфигов
restore_configs() {
    log "Восстановление конфигураций..."
    
    if tar xzf "$RESTORE_DIR/configs.tar.gz" \
           -C "$PROJECT_DIR" \
           --no-same-owner \
           --no-same-permissions \
           2>> "$LOG_FILE"; then
        success "Конфигурации восстановлены"
        return 0
    else
        if tail -n 10 "$LOG_FILE" | grep -q "Cannot utime"; then
            warning "Конфигурации восстановлены (не удалось обновить временные метки — обычно безопасно)"
            return 0
        else
            error "Ошибка восстановления конфигов"
            return 1
        fi
    fi
}

# Восстановление www
restore_www() {
    log "Восстановление www..."
    
    if tar xzf "$RESTORE_DIR/www.tar.gz" -C "$PROJECT_DIR" 2>> "$LOG_FILE"; then
        success "WWW восстановлен"
        return 0
    else
        error "Ошибка восстановления www"
        return 1
    fi
}

# Восстановление volumes
restore_volumes() {
    log "Восстановление volumes..."
    
    local volumes_dir="$RESTORE_DIR/volumes"
    
    if [ ! -d "$volumes_dir" ]; then
        warning "Volumes не найдены"
        return 0
    fi
    
    for volume_archive in "$volumes_dir"/*.tar.gz; do
        [ -f "$volume_archive" ] || continue
        
        local volume_name=$(basename "$volume_archive" .tar.gz)
        local full_volume_name="lepp-docker_${volume_name}"
        
        log "Восстановление: $full_volume_name"
        
        docker volume rm "$full_volume_name" 2>/dev/null
        docker volume create "$full_volume_name" >> "$LOG_FILE" 2>&1
        
        if docker run --rm -v "$full_volume_name:/volume" -v "$(dirname "$volume_archive"):/backup" alpine \
            sh -c "cd /volume && tar xzf /backup/$(basename "$volume_archive")" 2>> "$LOG_FILE"; then
            success "Volume $volume_name восстановлен"
        else
            error "Ошибка volume $volume_name"
        fi
    done
    
    return 0
}

# Запуск контейнеров
start_containers() {
    log "Запуск контейнеров..."
    
    cd "$PROJECT_DIR" || return 1
    
    if docker compose up -d 2>> "$LOG_FILE"; then
        success "Контейнеры запущены"
        log "Ожидание PostgreSQL..."
        sleep 10
        return 0
    else
        error "Ошибка запуска"
        return 1
    fi
}

# Восстановление БД
restore_database() {
    log "Восстановление базы данных..."
    
    local db_backup="$RESTORE_DIR/database.sql"
    
    if [ ! -f "$db_backup" ]; then
        error "Файл БД не найден"
        return 1
    fi
    
    docker exec "$DB_CONTAINER" psql -U "$POSTGRES_USER" -d postgres -c "DROP DATABASE IF EXISTS $POSTGRES_DB;" 2>> "$LOG_FILE"
    docker exec "$DB_CONTAINER" psql -U "$POSTGRES_USER" -d postgres -c "CREATE DATABASE $POSTGRES_DB;" 2>> "$LOG_FILE"
    
    if docker exec -i "$DB_CONTAINER" psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" < "$db_backup" 2>> "$LOG_FILE"; then
        success "База данных восстановлена"
        return 0
    else
        error "Ошибка восстановления БД"
        return 1
    fi
}

# Очистка
cleanup() {
    log "Очистка..."
    if [ -n "$RESTORE_DIR" ] && [ -d "$(dirname "$RESTORE_DIR")" ]; then
        rm -rf "$(dirname "$RESTORE_DIR")"
    fi
    success "Очистка завершена"
}

# Проверка
verify_restore() {
    log "Проверка..."
    echo ""
    docker compose ps
    echo ""
    info "Проверка БД:"
    docker exec "$DB_CONTAINER" psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "SELECT COUNT(*) FROM users;" 2>/dev/null || warning "Не удалось проверить БД"
}

# Главная функция
main() {
    echo "====================================="
    echo "  LEPP Stack Restore Script"
    echo "====================================="
    echo ""
    
    log "Начало восстановления"
    
    select_backup || exit 1
    confirm_restore || exit 1
    stop_containers || exit 1
    extract_backup || exit 1
    
    restore_configs || warning "Ошибка конфигов"
    restore_www || warning "Ошибка www"
    restore_volumes || warning "Ошибка volumes"
    
    start_containers || exit 1
    restore_database || warning "Ошибка БД"
    
    cleanup
    verify_restore
    
    echo ""
    success "=== Восстановление завершено ==="
}

main "$@"

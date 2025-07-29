#!/bin/bash

set -euo pipefail

BACKUP_TYPE="${1:-manual}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="mysql_backup_${BACKUP_TYPE}_${TIMESTAMP}.sql"
TEMP_DIR="/tmp/mysql_backup_${BACKUP_TYPE}_${TIMESTAMP}"
BACKUP_SUCCESS=false

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

cleanup() {
    if [ -d "${TEMP_DIR}" ]; then
        rm -rf "${TEMP_DIR}"
    fi
}

send_honeybadger_checkin() {
    if [ "${BACKUP_SUCCESS}" = true ]; then
        log "Sending Honeybadger check-in..."
        if curl -s -f -X POST "${HONEYBADGER_CHECKIN_URL}" > /dev/null 2>&1; then
            log "Honeybadger check-in sent successfully"
        else
            log "ERROR: Failed to send Honeybadger check-in"
            exit 1
        fi
    else
        log "Skipping Honeybadger check-in due to backup failure"
    fi
}

trap 'cleanup; send_honeybadger_checkin' EXIT

log "Starting ${BACKUP_TYPE} backup of MySQL"

mkdir -p "${TEMP_DIR}"

# Get list of databases to backup
log "Fetching databases..."
DATABASES=$(mysql -h "${MYSQL_HOST}" -P "${MYSQL_PORT}" -u "${MYSQL_USER}" -p"${MYSQL_PASSWORD}" -e "SHOW DATABASES;" -s --skip-column-names | grep -v -E "${EXCLUDE_DATABASES}")

if [ -z "${DATABASES}" ]; then
    log "No databases found to backup"
    exit 0
fi

# Backup each database
for DATABASE in ${DATABASES}; do
    log "Backing up database: ${DATABASE}"
    
    DATABASE_BACKUP_NAME="${DATABASE}_${BACKUP_TYPE}_${TIMESTAMP}.sql"
    BACKUP_FILE="${TEMP_DIR}/${DATABASE_BACKUP_NAME}"
    
    log "Creating dump for database: ${DATABASE}..."
    if mysqldump -h "${MYSQL_HOST}" -P "${MYSQL_PORT}" -u "${MYSQL_USER}" -p"${MYSQL_PASSWORD}" \
        --single-transaction \
        --quick \
        --lock-tables=false \
        --routines \
        --triggers \
        --events \
        --max_allowed_packet=1G \
        "${DATABASE}" > "${BACKUP_FILE}"; then
        log "Database dump created: ${DATABASE_BACKUP_NAME}"
    else
        log "ERROR: Failed to create dump for database ${DATABASE}"
        exit 1
    fi
    
    if [ ! -f "${BACKUP_FILE}" ]; then
        log "ERROR: Backup file not created for database ${DATABASE}"
        exit 1
    fi
    
    log "Compressing backup..."
    nice -n 10 ionice -c 3 zstd -7 -T7 --rm "${BACKUP_FILE}"
    COMPRESSED_FILE="${BACKUP_FILE}.zst"
    
    S3_PATH="s3://${S3_BUCKET}/${S3_PREFIX}/${DATABASE}/${BACKUP_TYPE}/${DATABASE_BACKUP_NAME}.zst"
    log "Uploading to S3: ${S3_PATH}"
    aws s3 cp "${COMPRESSED_FILE}" "${S3_PATH}" --endpoint-url "${S3_ENDPOINT_URL}" --no-progress
    
    log "Completed backup for database: ${DATABASE}"
done

rotate_backups() {
    local backup_type=$1
    local retention_count=$2
    
    log "Rotating ${backup_type} backups, keeping ${retention_count} most recent"
    
    # Rotate backups for each database
    for DATABASE in ${DATABASES}; do
        log "Rotating ${backup_type} backups for database: ${DATABASE}"
        
        aws s3 ls "s3://${S3_BUCKET}/${S3_PREFIX}/${DATABASE}/${backup_type}/" --endpoint-url "${S3_ENDPOINT_URL}" 2>/dev/null | \
            sort -k1,2 | \
            head -n -${retention_count} | \
            awk '{print $4}' | \
            while read -r file; do
                if [ -n "${file}" ]; then
                    log "Deleting old backup: ${file}"
                    aws s3 rm "s3://${S3_BUCKET}/${S3_PREFIX}/${DATABASE}/${backup_type}/${file}" --endpoint-url "${S3_ENDPOINT_URL}"
                fi
            done
    done
}

case "${BACKUP_TYPE}" in
    initial)
        rotate_backups "initial" "1"  # Keep only the most recent initial backup
        ;;
    hourly)
        rotate_backups "hourly" "${RETENTION_HOURLY}"
        ;;
    daily)
        rotate_backups "daily" "${RETENTION_DAILY}"
        ;;
    weekly)
        rotate_backups "weekly" "${RETENTION_WEEKLY}"
        ;;
    monthly)
        rotate_backups "monthly" "${RETENTION_MONTHLY}"
        ;;
esac

BACKUP_SUCCESS=true
log "Backup completed successfully"
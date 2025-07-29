#!/bin/bash

set -e

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

if [ -z "${MYSQL_HOST}" ]; then
    log "ERROR: MYSQL_HOST environment variable is required"
    exit 1
fi

if [ -z "${MYSQL_USER}" ]; then
    log "ERROR: MYSQL_USER environment variable is required"
    exit 1
fi

if [ -z "${MYSQL_PASSWORD}" ]; then
    log "ERROR: MYSQL_PASSWORD environment variable is required"
    exit 1
fi

if [ -z "${S3_BUCKET}" ]; then
    log "ERROR: S3_BUCKET environment variable is required"
    exit 1
fi

if [ -z "${S3_ENDPOINT_URL}" ]; then
    log "ERROR: S3_ENDPOINT_URL environment variable is required"
    exit 1
fi

if [ -z "${AWS_ACCESS_KEY_ID}" ] || [ -z "${AWS_SECRET_ACCESS_KEY}" ]; then
    log "ERROR: AWS credentials (AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY) are required"
    exit 1
fi

if [ -z "${HONEYBADGER_CHECKIN_URL}" ]; then
    log "ERROR: HONEYBADGER_CHECKIN_URL environment variable is required"
    exit 1
fi

touch /var/log/mysql-backup.log

log "Starting MySQL backup service"
log "Configuration:"
log "  - MySQL Host: ${MYSQL_HOST}:${MYSQL_PORT}"
log "  - MySQL User: ${MYSQL_USER}"
log "  - Excluded databases: ${EXCLUDE_DATABASES}"
log "  - S3 Bucket: ${S3_BUCKET}"
log "  - S3 Prefix: ${S3_PREFIX}"
log "  - Retention: Hourly=${RETENTION_HOURLY}, Daily=${RETENTION_DAILY}, Weekly=${RETENTION_WEEKLY}, Monthly=${RETENTION_MONTHLY}"

# Export environment variables for cron
printenv | grep -E '^(MYSQL_|S3_|AWS_|RETENTION_|HONEYBADGER_|PATH=|EXCLUDE_)' > /etc/environment

log "Waiting for MySQL to be available..."
log "mysql -h \"${MYSQL_HOST}\" -P \"${MYSQL_PORT}\" -u \"${MYSQL_USER}\" -p\"${MYSQL_PASSWORD}\" -e \"SELECT 1\""
until mysql -h "${MYSQL_HOST}" -P "${MYSQL_PORT}" -u "${MYSQL_USER}" -p"${MYSQL_PASSWORD}" -e "SELECT 1" > /dev/null 2>&1; do
    log "MySQL not ready, retrying in 5 seconds..."
    sleep 5
done
log "MySQL is available"

if [ "${SKIP_INITIAL_BACKUP:-false}" = "false" ]; then
    log "Running initial backup..."
    /app/backup-mysql.sh initial 2>&1 | tee -a /var/log/mysql-backup.log
else
    log "Skipping initial backup (SKIP_INITIAL_BACKUP=true)"
fi

log "Starting cron daemon..."
cron

tail -f /var/log/mysql-backup.log
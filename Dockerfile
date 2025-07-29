FROM ubuntu:latest

RUN apt-get update && apt-get install -y \
    cron \
    curl \
    gzip \
    zstd \
    jq \
    ca-certificates \
    python3 \
    python3-venv \
    iputils-ping \
    dnsutils \
    mariadb-client \
    && rm -rf /var/lib/apt/lists/* \
    && curl -LsSf https://astral.sh/uv/install.sh | sh \
    && /root/.local/bin/uv venv /opt/venv \
    && /root/.local/bin/uv pip install --python /opt/venv/bin/python awscli

ENV PATH="/opt/venv/bin:$PATH"

WORKDIR /app

COPY backup-mysql.sh /app/backup-mysql.sh
COPY cron-schedule /etc/cron.d/mysql-backup
COPY entrypoint.sh /app/entrypoint.sh

RUN chmod +x /app/backup-mysql.sh /app/entrypoint.sh \
    && chmod 0644 /etc/cron.d/mysql-backup \
    && crontab /etc/cron.d/mysql-backup

ENV MYSQL_HOST=mysql
ENV MYSQL_PORT=3306
ENV MYSQL_USER=root
ENV MYSQL_PASSWORD=
ENV EXCLUDE_DATABASES="information_schema|performance_schema|mysql|sys"
ENV S3_BUCKET=
ENV S3_PREFIX=mysql-backups
ENV S3_ENDPOINT_URL=
ENV AWS_ACCESS_KEY_ID=
ENV AWS_SECRET_ACCESS_KEY=
ENV AWS_DEFAULT_REGION=us-east-1
ENV RETENTION_HOURLY=24
ENV RETENTION_DAILY=7
ENV RETENTION_WEEKLY=4
ENV RETENTION_MONTHLY=12
ENV HONEYBADGER_CHECKIN_URL=
ENV SKIP_INITIAL_BACKUP=false

ENTRYPOINT ["/app/entrypoint.sh"]
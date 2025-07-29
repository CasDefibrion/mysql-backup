# MySQL/MariaDB Backup System

An automated backup solution for MySQL/MariaDB databases with S3 storage, compression, and retention management.

## Features

- 🔄 Automated scheduled backups (hourly, daily, weekly, monthly)
- 🗜️ Compression using zstd for efficient storage
- ☁️ S3-compatible storage support
- 🔍 Automatic database discovery
- 📊 Retention policy management
- 🔔 Honeybadger monitoring integration
- 🐳 Fully containerized with Docker

## Requirements

- Docker and Docker Compose
- MariaDB/MySQL server (local or remote)
- S3-compatible storage (AWS S3, MinIO, etc.)
- Honeybadger account (for monitoring)

## Quick Start

1. Copy the example configuration:
   ```bash
   cp docker-compose.yml.example docker-compose.yml
   ```

2. Edit `docker-compose.yml` with your credentials:
   - Database connection settings
   - S3 bucket and credentials
   - Honeybadger check-in URL

3. Build and start the backup service:
   ```bash
   docker compose build
   docker compose up -d
   ```

4. Check logs to verify it's working:
   ```bash
   docker compose logs -f mysql-backup
   ```

## Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `MYSQL_HOST` | MariaDB/MySQL host | `localhost` |
| `MYSQL_PORT` | Database port | `3306` |
| `MYSQL_USER` | Database user | `root` |
| `MYSQL_PASSWORD` | Database password | *(required)* |
| `EXCLUDE_DATABASES` | Regex pattern for databases to exclude | `information_schema\|performance_schema\|mysql\|sys` |
| `S3_BUCKET` | S3 bucket name | *(required)* |
| `S3_PREFIX` | S3 path prefix | `mysql-backups` |
| `S3_ENDPOINT_URL` | S3 endpoint URL | *(required)* |
| `AWS_ACCESS_KEY_ID` | AWS access key | *(required)* |
| `AWS_SECRET_ACCESS_KEY` | AWS secret key | *(required)* |
| `AWS_DEFAULT_REGION` | AWS region | `us-east-1` |
| `RETENTION_HOURLY` | Number of hourly backups to keep | `24` |
| `RETENTION_DAILY` | Number of daily backups to keep | `7` |
| `RETENTION_WEEKLY` | Number of weekly backups to keep | `4` |
| `RETENTION_MONTHLY` | Number of monthly backups to keep | `12` |
| `HONEYBADGER_CHECKIN_URL` | Honeybadger check-in URL | *(required)* |
| `SKIP_INITIAL_BACKUP` | Skip backup on container start | `false` |

### Backup Schedule

The default backup schedule (configured in `cron-schedule`):

- **Hourly**: Every hour at minute 0
- **Daily**: Every day at 2:15 AM
- **Weekly**: Every Sunday at 3:30 AM
- **Monthly**: First day of month at 4:45 AM

## S3 Storage Structure

Backups are organized in S3 as follows:

```
s3://your-bucket/
└── mysql-backups/
    └── database_name/
        ├── hourly/
        │   └── database_name_hourly_20250729_120000.sql.zst
        ├── daily/
        │   └── database_name_daily_20250729_021500.sql.zst
        ├── weekly/
        │   └── database_name_weekly_20250729_033000.sql.zst
        └── monthly/
            └── database_name_monthly_20250729_044500.sql.zst
```

## Backup Process

1. **Database Discovery**: Automatically discovers all databases except those matching the exclude pattern
2. **Dump Creation**: Uses `mysqldump` with optimized settings for large databases
3. **Compression**: Compresses dumps using zstd with 7 threads
4. **Upload**: Uploads compressed backups to S3
5. **Rotation**: Removes old backups based on retention settings
6. **Monitoring**: Sends check-in to Honeybadger on successful completion

## Restore Process

To restore a backup:

1. Download the backup from S3:
   ```bash
   aws s3 cp s3://your-bucket/mysql-backups/database_name/daily/backup.sql.zst backup.sql.zst
   ```

2. Decompress the backup:
   ```bash
   zstd -d backup.sql.zst
   ```

3. Restore to MySQL/MariaDB:
   ```bash
   mysql -h host -u user -p database_name < backup.sql
   ```

## Monitoring

The system sends check-ins to Honeybadger after each successful backup. Configure alerts in Honeybadger to be notified if backups fail or don't run.

#!/bin/sh
set -e
mkdir -p /data
dbmate create
dbmate up

# Database backup to S3-compatible storage (Tigris)
if [ -n "$AWS_ACCESS_KEY_ID" ] && [ -n "$AWS_SECRET_ACCESS_KEY" ] && [ -n "$S3_BUCKET" ]; then
    BACKUP_FILENAME="db_backup_$(date +%Y%m%d_%H%M%S).db"
    DB_PATH="${DATABASE_URL#*:}"  # Extracts the database path from DATABASE_URL

    if [ -f "$DB_PATH" ]; then
        # Create a timestamped backup
        cp "$DB_PATH" "/tmp/$BACKUP_FILENAME"
        
        # Upload to S3-compatible storage
        aws --endpoint-url "$S3_ENDPOINT" s3 cp \
            "/tmp/$BACKUP_FILENAME" \
            "s3://$S3_BUCKET/$BACKUP_FILENAME" \
            --no-verify-ssl  # Only if using self-signed certificates

        # Clean up local backup
        rm -f "/tmp/$BACKUP_FILENAME"
        echo "Database backup uploaded to S3: $BACKUP_FILENAME"
    else
        echo "Warning: Database file not found at $DB_PATH, skipping backup"
    fi
else
    echo "Warning: AWS credentials or S3_BUCKET not set, skipping backup"
fi

exec ./entrypoint.sh "$@"
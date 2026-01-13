#!/usr/bin/env bash
set -euo pipefail

# Restore the latest db_backup_*.db from S3 into data/jimgym.db
# If data/jimgym.db already exists, move it into data/archive/ with a timestamped name.

# Determine project root (script may be called from anywhere)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd 2>/dev/null || echo "$SCRIPT_DIR")"
cd "$REPO_ROOT"

# Load environment variables from .env if present
if [ -f .env ]; then
  # shellcheck disable=SC1091
  . ./.env
fi

# Validate required env vars
: "${S3_BUCKET:?S3_BUCKET is required}"
: "${S3_ENDPOINT:?S3_ENDPOINT is required}"
: "${AWS_ACCESS_KEY_ID:?AWS_ACCESS_KEY_ID is required}"
: "${AWS_SECRET_ACCESS_KEY:?AWS_SECRET_ACCESS_KEY is required}"

# Check aws CLI
if ! command -v aws >/dev/null 2>&1; then
  echo "Error: aws CLI not found. Install aws-cli and retry." >&2
  exit 1
fi

DATA_DIR="$REPO_ROOT/data"
ARCHIVE_DIR="$DATA_DIR/archive"
DB_FILE="$DATA_DIR/jimgym.db"
TMP_DL="$DATA_DIR/.download.tmp.db"

mkdir -p "$DATA_DIR" "$ARCHIVE_DIR"

# Archive existing DB if present
if [ -f "$DB_FILE" ]; then
  TS="$(date +%Y%m%d_%H%M%S)"
  mv "$DB_FILE" "$ARCHIVE_DIR/jimgym.db.$TS"
  echo "Archived existing DB to $ARCHIVE_DIR/jimgym.db.$TS"
fi

# Find latest backup key in the bucket
# Output format from `aws s3 ls`: YYYY-MM-DD HH:MM:SS size key
LATEST_LINE="$(aws --endpoint-url "$S3_ENDPOINT" s3 ls "s3://$S3_BUCKET/" | grep 'db_backup_.*\.db' | sort | tail -n 1 || true)"
if [ -z "$LATEST_LINE" ]; then
  echo "Error: No db_backup_*.db objects found in s3://$S3_BUCKET/" >&2
  exit 1
fi

LATEST_KEY="$(printf "%s" "$LATEST_LINE" | awk '{print $4}')"
if [ -z "$LATEST_KEY" ]; then
  echo "Error: Failed to parse latest backup key from: $LATEST_LINE" >&2
  exit 1
fi

echo "Latest backup: s3://$S3_BUCKET/$LATEST_KEY"

# Download to temp then move into place
aws --endpoint-url "$S3_ENDPOINT" s3 cp "s3://$S3_BUCKET/$LATEST_KEY" "$TMP_DL" --no-verify-ssl
mv -f "$TMP_DL" "$DB_FILE"

echo "Restored backup to $DB_FILE"
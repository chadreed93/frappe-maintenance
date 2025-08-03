#!/bin/bash

# -----------------------------
# Frappe Cleanup & Maintenance
# -----------------------------

# Variables
BENCH_PATH="/home/ubuntu/frappe-bench"
SITES_DIR="$BENCH_PATH/sites"
DATE=$(date +"%Y-%m-%d_%H-%M-%S")
LOGFILE="$BENCH_PATH/maintenance_logs/maintain_$DATE.log"

# Create logs folder if missing
mkdir -p "$BENCH_PATH/maintenance_logs"

echo "🔧 Starting Frappe Cleanup and Maintenance Script..." | tee -a "$LOGFILE"
cd "$BENCH_PATH" || exit 1

# 1. Clean __pycache__ and .pyc
echo "🧹 Removing __pycache__ and *.pyc files..." | tee -a "$LOGFILE"
find . -name '__pycache__' -exec rm -rf {} + >> "$LOGFILE" 2>&1
find . -name '*.pyc' -exec rm -f {} + >> "$LOGFILE" 2>&1

# 2. Backup each site
echo "💾 Creating full backup (with files) for each site..." | tee -a "$LOGFILE"
for site_path in "$SITES_DIR"/*; do
  [ -d "$site_path" ] || continue
  SITE=$(basename "$site_path")
  # skip non-site folders
  [[ "$SITE" =~ ^(assets|common_site_config.json)$ ]] && continue

  echo "  • Backing up $SITE ..." | tee -a "$LOGFILE"
  bench --site "$SITE" backup --with-files >> "$LOGFILE" 2>&1
done

# 3. Update apps (patches only)
echo "⬆️ Updating installed apps with patches across the bench..." | tee -a "$LOGFILE"
bench update --patch >> "$LOGFILE" 2>&1

# 4. Rebuild and prepare
echo "🔨 Rebuilding setup and assets..." | tee -a "$LOGFILE"
bench setup requirements >> "$LOGFILE" 2>&1
bench setup redis >> "$LOGFILE" 2>&1
bench setup socketio >> "$LOGFILE" 2>&1

echo "🧱 Building all assets..." | tee -a "$LOGFILE"
bench build >> "$LOGFILE" 2>&1

# 5. Clear cache & migrate each site
echo "🧼 Clearing cache and running DB migrations for each site..." | tee -a "$LOGFILE"
for site_path in "$SITES_DIR"/*; do
  [ -d "$site_path" ] || continue
  SITE=$(basename "$site_path")
  [[ "$SITE" =~ ^(assets|common_site_config.json)$ ]] && continue

  echo "  • Clearing cache for $SITE ..." | tee -a "$LOGFILE"
  bench --site "$SITE" clear-cache >> "$LOGFILE" 2>&1

  echo "  • Migrating $SITE ..." | tee -a "$LOGFILE"
  bench --site "$SITE" migrate >> "$LOGFILE" 2>&1
done

# 6. Restart services
echo "🔁 Restarting Supervisor services..." | tee -a "$LOGFILE"
sudo supervisorctl restart all >> "$LOGFILE" 2>&1

echo "✅ Maintenance Completed: $DATE" | tee -a "$LOGFILE"

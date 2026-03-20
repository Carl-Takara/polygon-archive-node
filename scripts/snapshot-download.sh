#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Snapshot Download Helper
# Run on the server to download and extract Erigon snapshot
# ============================================================

PROJECT_DIR="/opt/polygon-node"
source "$PROJECT_DIR/.env"

SNAPSHOT_URL="${1:-}"

if [ -z "$SNAPSHOT_URL" ]; then
  echo "Usage: $0 <snapshot-url>"
  echo ""
  echo "Get the latest Polygon Erigon Archive snapshot URL from:"
  echo "  https://publicnode.com/snapshots"
  echo ""
  echo "Example:"
  echo "  $0 https://snapshots.publicnode.com/polygon-mainnet-erigon-archive-XXXXXX.tar.lz4"
  exit 1
fi

echo "============================================"
echo "  Polygon Erigon Archive Snapshot Download"
echo "============================================"
echo "  URL:  $SNAPSHOT_URL"
echo "  Dest: ${ERIGON_DATA_DIR}"
echo ""

# ---- Check disk space ----
AVAILABLE_GB=$(df -BG "${ERIGON_DATA_DIR}" | tail -1 | awk '{print $4}' | tr -d 'G')
echo "  Available disk: ${AVAILABLE_GB}GB"

if [ "$AVAILABLE_GB" -lt 3000 ]; then
  echo "  WARNING: Less than 3TB available. Archive node needs ~2-3TB."
  read -p "  Continue anyway? [y/N] " -n 1 -r
  echo ""
  [[ $REPLY =~ ^[Yy]$ ]] || exit 0
fi

# ---- Stop Erigon if running ----
echo "[*] Stopping Erigon if running..."
cd "$PROJECT_DIR"
docker-compose stop erigon 2>/dev/null || true

# ---- Download and extract ----
echo "[*] Downloading and extracting snapshot..."
echo "    This will take several hours depending on your bandwidth."
echo ""

# Use wget with resume support, pipe through lz4 and tar
wget -c -O - "$SNAPSHOT_URL" | lz4 -dc | pv | tar xf - -C "${ERIGON_DATA_DIR}"

echo ""
echo "[*] Snapshot extracted successfully!"
echo ""

# ---- Restart Erigon ----
echo "[*] Starting Erigon..."
docker-compose up -d erigon

echo ""
echo "============================================"
echo "  Snapshot Import Complete!"
echo "============================================"
echo "  Erigon will now sync from the snapshot's latest block."
echo "  Monitor: bash $PROJECT_DIR/scripts/monitor.sh"
echo "============================================"

#!/usr/bin/env bash
set -euo pipefail

echo "=== Polygon Archive Node (Erigon) Setup ==="

# ---- Check prerequisites ----
for cmd in docker docker-compose; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "Error: $cmd is not installed."
    exit 1
  fi
done

# ---- Create .env if missing ----
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

if [ ! -f "$PROJECT_DIR/.env" ]; then
  cp "$PROJECT_DIR/.env.example" "$PROJECT_DIR/.env"
  echo "Created .env from .env.example — please edit it with your ETH_RPC_URL."
  echo "  vi $PROJECT_DIR/.env"
  exit 0
fi

# ---- Source env ----
source "$PROJECT_DIR/.env"

# ---- Validate required vars ----
if [[ "$ETH_RPC_URL" == *"YOUR_API_KEY"* ]]; then
  echo "Error: Please set a valid ETH_RPC_URL in .env"
  exit 1
fi

# ---- Create data directories ----
echo "Creating data directories..."
mkdir -p "${ERIGON_DATA_DIR:-$PROJECT_DIR/data/erigon}"
mkdir -p "${HEIMDALL_DATA_DIR:-$PROJECT_DIR/data/heimdall}"

# ---- System tuning recommendations ----
echo ""
echo "=== System Tuning Recommendations ==="
echo "Run these commands on your server for optimal performance:"
echo ""
echo "  # Increase open file limits"
echo "  echo 'fs.file-max = 1048576' | sudo tee -a /etc/sysctl.conf"
echo "  echo '* soft nofile 65536' | sudo tee -a /etc/security/limits.conf"
echo "  echo '* hard nofile 65536' | sudo tee -a /etc/security/limits.conf"
echo ""
echo "  # Optimize for SSD / NVMe"
echo "  echo 'vm.swappiness = 10' | sudo tee -a /etc/sysctl.conf"
echo "  echo 'vm.dirty_ratio = 40' | sudo tee -a /etc/sysctl.conf"
echo "  echo 'vm.dirty_background_ratio = 10' | sudo tee -a /etc/sysctl.conf"
echo ""
echo "  sudo sysctl -p"
echo ""

# ---- Pull images ----
echo "Pulling Docker images..."
cd "$PROJECT_DIR"
docker-compose pull

echo ""
echo "=== Setup Complete ==="
echo "Start the node:  cd $PROJECT_DIR && docker-compose up -d"
echo "View logs:        docker-compose logs -f"
echo "Check sync:       curl -s localhost:8545 -X POST -H 'Content-Type: application/json' -d '{\"jsonrpc\":\"2.0\",\"method\":\"eth_syncing\",\"params\":[],\"id\":1}'"

#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Remote Setup Script - Runs on the Dedicated Server
# ============================================================

PROJECT_DIR="/opt/polygon-node"
source "$PROJECT_DIR/.env"

echo "========================================"
echo "  Phase 1: System Setup"
echo "========================================"

# ---- System update ----
echo "[*] Updating system packages..."
apt-get update -qq && apt-get upgrade -y -qq

# ---- Install dependencies ----
echo "[*] Installing dependencies..."
apt-get install -y -qq \
  curl wget lz4 pv htop iotop \
  ca-certificates gnupg lsb-release \
  ufw fail2ban

# ---- Install Docker if missing ----
if ! command -v docker &>/dev/null; then
  echo "[*] Installing Docker..."
  curl -fsSL https://get.docker.com | sh
  systemctl enable docker
  systemctl start docker
fi

# ---- Install Docker Compose if missing ----
if ! command -v docker-compose &>/dev/null; then
  echo "[*] Installing Docker Compose..."
  COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep '"tag_name"' | cut -d'"' -f4)
  curl -L "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" \
    -o /usr/local/bin/docker-compose
  chmod +x /usr/local/bin/docker-compose
fi

echo "  Docker:         $(docker --version)"
echo "  Docker Compose: $(docker-compose --version)"

echo ""
echo "========================================"
echo "  Phase 2: System Tuning"
echo "========================================"

# ---- Kernel parameters ----
echo "[*] Tuning kernel parameters..."
cat > /etc/sysctl.d/99-polygon-node.conf <<'SYSCTL'
# File descriptors
fs.file-max = 1048576

# Network tuning
net.core.somaxconn = 65535
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_max_syn_backlog = 65535

# SSD/NVMe optimization
vm.swappiness = 10
vm.dirty_ratio = 40
vm.dirty_background_ratio = 10
vm.vfs_cache_pressure = 50
SYSCTL
sysctl -p /etc/sysctl.d/99-polygon-node.conf

# ---- File descriptor limits ----
cat > /etc/security/limits.d/99-polygon-node.conf <<'LIMITS'
* soft nofile 65536
* hard nofile 65536
root soft nofile 65536
root hard nofile 65536
LIMITS

echo ""
echo "========================================"
echo "  Phase 3: Firewall Setup"
echo "========================================"

echo "[*] Configuring UFW firewall..."
ufw --force reset
ufw default deny incoming
ufw default allow outgoing

# SSH
ufw allow 22/tcp comment 'SSH'

# Erigon RPC (restrict to your IP if possible)
ufw allow 8545/tcp comment 'Erigon HTTP RPC'
ufw allow 8546/tcp comment 'Erigon WebSocket'

# P2P networking (must be open)
ufw allow 30303/tcp comment 'Erigon P2P TCP'
ufw allow 30303/udp comment 'Erigon P2P UDP'
ufw allow 42069/tcp comment 'Erigon Torrent'

# Heimdall P2P
ufw allow 26656/tcp comment 'Heimdall P2P'
ufw allow 26657/tcp comment 'Heimdall RPC'

ufw --force enable
ufw status numbered

echo ""
echo "========================================"
echo "  Phase 4: Data Directory Setup"
echo "========================================"

# ---- Detect and prepare storage ----
echo "[*] Creating data directories..."
mkdir -p "${ERIGON_DATA_DIR}"
mkdir -p "${HEIMDALL_DATA_DIR}"

# Show disk info
echo "[*] Disk layout:"
lsblk -o NAME,SIZE,TYPE,MOUNTPOINT
echo ""
df -h "${ERIGON_DATA_DIR}"

echo ""
echo "========================================"
echo "  Phase 5: Snapshot Download"
echo "========================================"

if [ "${USE_SNAPSHOT:-false}" = "true" ]; then
  echo "[*] Checking for Erigon snapshot..."

  # Check if data already exists
  if [ -d "${ERIGON_DATA_DIR}/chaindata" ] && [ "$(ls -A ${ERIGON_DATA_DIR}/chaindata 2>/dev/null)" ]; then
    echo "  Erigon data directory already has data, skipping snapshot download."
  else
    echo "  Snapshot download is recommended for faster sync."
    echo "  Visit https://publicnode.com/snapshots to get the latest Polygon Erigon Archive snapshot URL."
    echo ""
    echo "  To manually download later:"
    echo "    wget -O /tmp/polygon-erigon.tar.lz4 <SNAPSHOT_URL>"
    echo "    lz4 -dc /tmp/polygon-erigon.tar.lz4 | pv | tar xf - -C ${ERIGON_DATA_DIR}"
    echo ""
    echo "  Or use Erigon's built-in torrent downloader (automatic on startup)."
  fi
else
  echo "[*] Snapshot download disabled. Erigon will use built-in torrent sync."
fi

echo ""
echo "========================================"
echo "  Phase 6: Start Services"
echo "========================================"

cd "$PROJECT_DIR"

echo "[*] Pulling Docker images..."
docker-compose pull

echo "[*] Starting Heimdall + Erigon..."
docker-compose up -d

echo "[*] Waiting 10s for services to initialize..."
sleep 10

echo "[*] Service status:"
docker-compose ps

echo ""
echo "[*] Checking Erigon RPC..."
SYNC_STATUS=$(curl -s --max-time 5 http://localhost:8545 \
  -X POST -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_syncing","params":[],"id":1}' 2>/dev/null || echo '{"error":"not ready yet"}')
echo "  $SYNC_STATUS"

echo ""
echo "========================================"
echo "  Setup Complete!"
echo "========================================"
echo ""
echo "  Useful commands:"
echo "    docker-compose -f $PROJECT_DIR/docker-compose.yml logs -f erigon"
echo "    docker-compose -f $PROJECT_DIR/docker-compose.yml logs -f heimdall"
echo "    bash $PROJECT_DIR/scripts/monitor.sh"
echo ""

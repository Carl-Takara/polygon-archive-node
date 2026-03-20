#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Polygon Archive Node (Erigon) - One-Click Deploy
# Target: Interserver Dedicated Server
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---- Load config ----
if [ ! -f "$SCRIPT_DIR/.env" ]; then
  cp "$SCRIPT_DIR/.env.example" "$SCRIPT_DIR/.env"
  echo "Created .env from template. Please edit it first:"
  echo "  vi $SCRIPT_DIR/.env"
  echo ""
  echo "At minimum, set ETH_RPC_URL to a valid Ethereum mainnet RPC."
  exit 1
fi

source "$SCRIPT_DIR/.env"

# ---- Validate ----
if [[ "$ETH_RPC_URL" == *"YOUR_API_KEY"* ]]; then
  echo "Error: Set a valid ETH_RPC_URL in .env"
  exit 1
fi

echo "============================================"
echo "  Polygon Archive Node - One-Click Deploy"
echo "============================================"
echo "  Server:    ${SERVER_USER}@${SERVER_IP}"
echo "  Hostname:  ${SERVER_HOSTNAME}"
echo "  Snapshot:  ${USE_SNAPSHOT:-false}"
echo "============================================"
echo ""
read -p "Continue? [y/N] " -n 1 -r
echo ""
[[ $REPLY =~ ^[Yy]$ ]] || exit 0

# ---- Upload files to server ----
echo "[1/5] Uploading configuration to server..."
ssh "${SERVER_USER}@${SERVER_IP}" "mkdir -p /opt/polygon-node/scripts"
scp "$SCRIPT_DIR/docker-compose.yml" "${SERVER_USER}@${SERVER_IP}:/opt/polygon-node/"
scp "$SCRIPT_DIR/.env" "${SERVER_USER}@${SERVER_IP}:/opt/polygon-node/"
scp "$SCRIPT_DIR/scripts/remote-setup.sh" "${SERVER_USER}@${SERVER_IP}:/opt/polygon-node/scripts/"
scp "$SCRIPT_DIR/scripts/monitor.sh" "${SERVER_USER}@${SERVER_IP}:/opt/polygon-node/scripts/"

# ---- Execute remote setup ----
echo "[2/5] Running remote setup on server..."
ssh -t "${SERVER_USER}@${SERVER_IP}" "chmod +x /opt/polygon-node/scripts/*.sh && bash /opt/polygon-node/scripts/remote-setup.sh"

echo ""
echo "============================================"
echo "  Deploy Complete!"
echo "============================================"
echo ""
echo "  RPC Endpoint:  http://${SERVER_IP}:8545"
echo "  WS Endpoint:   ws://${SERVER_IP}:8546"
echo ""
echo "  Monitor:       ssh ${SERVER_USER}@${SERVER_IP} 'bash /opt/polygon-node/scripts/monitor.sh'"
echo "  Logs:          ssh ${SERVER_USER}@${SERVER_IP} 'cd /opt/polygon-node && docker compose logs -f'"
echo "  Stop:          ssh ${SERVER_USER}@${SERVER_IP} 'cd /opt/polygon-node && docker compose down'"
echo ""
echo "  IMPORTANT: Change your root password!"
echo "    ssh ${SERVER_USER}@${SERVER_IP} 'passwd'"
echo "============================================"

#!/usr/bin/env bash
set -euo pipefail

RPC_URL="${1:-http://localhost:8545}"

echo "=== Polygon Archive Node Monitor ==="
echo "RPC: $RPC_URL"
echo ""

# ---- Sync status ----
sync_result=$(curl -s "$RPC_URL" -X POST \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_syncing","params":[],"id":1}')

echo "Sync Status:"
echo "$sync_result" | python3 -m json.tool 2>/dev/null || echo "$sync_result"
echo ""

# ---- Latest block ----
block_result=$(curl -s "$RPC_URL" -X POST \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}')

block_hex=$(echo "$block_result" | python3 -c "import sys,json; print(json.load(sys.stdin).get('result','0x0'))" 2>/dev/null || echo "0x0")
block_dec=$(python3 -c "print(int('$block_hex', 16))" 2>/dev/null || echo "unknown")

echo "Latest Block: $block_dec ($block_hex)"
echo ""

# ---- Container status ----
echo "Container Status:"
docker ps --filter "name=erigon" --filter "name=heimdall" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
echo ""

# ---- Disk usage ----
echo "Disk Usage:"
if [ -d "${ERIGON_DATA_DIR:-./data/erigon}" ]; then
  du -sh "${ERIGON_DATA_DIR:-./data/erigon}" 2>/dev/null || echo "  Erigon data dir not accessible"
fi
if [ -d "${HEIMDALL_DATA_DIR:-./data/heimdall}" ]; then
  du -sh "${HEIMDALL_DATA_DIR:-./data/heimdall}" 2>/dev/null || echo "  Heimdall data dir not accessible"
fi

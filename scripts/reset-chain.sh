#!/bin/bash
# =============================================================================
#  reset-chain.sh · lab Bitcoin UMA 2026
# -----------------------------------------------------------------------------
#  Borra el regtest local y vuelve a arrancar bitcoind desde cero. Útil como
#  "plan B" si un alumno rompe su nodo (wallet corrupto, bloques inconsistentes,
#  etc.) y queremos volver a un estado limpio sin recrear el contenedor.
#
#  Destruye:  ~/.bitcoin/regtest  (bloques, chainstate, wallets)
#  Conserva:  ~/.bitcoin/bitcoin.conf (la configuración no se toca)
#
#  Para un reset más agresivo (volumen Docker completo) el instructor usa
#  `docker compose down -v` desde el host.
#
#  Uso (dentro del contenedor del alumno):
#      reset-chain.sh
# =============================================================================
set -euo pipefail

echo ">> Parando bitcoind (si está corriendo)..."
bitcoin-cli stop 2>/dev/null || true

# Esperar a que el proceso termine de verdad antes de borrar el datadir.
for _ in $(seq 1 15); do
    pgrep -x bitcoind >/dev/null || break
    sleep 1
done

if pgrep -x bitcoind >/dev/null; then
    echo "   bitcoind no responde, forzando kill..."
    pkill -9 bitcoind || true
    sleep 1
fi

echo ">> Borrando ~/.bitcoin/regtest..."
rm -rf "$HOME/.bitcoin/regtest"

echo ">> Arrancando bitcoind de nuevo..."
bitcoind -daemon

echo ">> Esperando a que el RPC esté listo..."
bitcoin-cli -rpcwait getblockchaininfo | jq '{chain, blocks, bestblockhash}'

echo
echo ">> Reset completo."
echo "   El wallet también se borró. Para recrearlo:"
echo "       bitcoin-cli createwallet \"lab\""

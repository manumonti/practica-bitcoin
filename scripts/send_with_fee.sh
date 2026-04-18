#!/bin/bash
# =============================================================================
#  send_with_fee.sh · lab Bitcoin UMA 2026
# -----------------------------------------------------------------------------
#  Envía BTC a una dirección con un fee rate explícito (sat/vB), y muestra el
#  tamaño virtual y el fee real que ha acabado pagando la transacción.
#  Pensado para el Bloque 4 ("mempool como mercado"), donde los alumnos
#  disparan varias tx simultáneas con distintos fee rates y observan cómo
#  compiten por entrar en el siguiente bloque.
#
#  Uso (dentro del contenedor del alumno):
#      send_with_fee.sh <dirección_destino> <cantidad_btc> <fee_rate_sat_vb>
#
#  Ejemplo:
#      send_with_fee.sh bcrt1q... 0.1 25
# =============================================================================
set -euo pipefail

if [[ $# -ne 3 ]]; then
    echo "Uso: $0 <destino> <cantidad_btc> <fee_rate_sat_vb>" >&2
    exit 1
fi

DEST="$1"
AMOUNT="$2"
FEE_RATE="$3"

TXID=$(bitcoin-cli -named sendtoaddress \
    address="$DEST" \
    amount="$AMOUNT" \
    fee_rate="$FEE_RATE")

echo "txid: $TXID"
bitcoin-cli getmempoolentry "$TXID" \
    | jq '{vsize, fee_btc: .fees.base, fee_rate_sat_vb: ((.fees.base * 100000000) / .vsize)}'

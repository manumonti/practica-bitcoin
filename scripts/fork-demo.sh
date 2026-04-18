#!/bin/bash
# =============================================================================
#  fork-demo.sh · lab Bitcoin UMA 2026
# -----------------------------------------------------------------------------
#  Orquesta la demo de fork y reorganización del Bloque 3.
#
#  Se ejecuta desde el HOST de la VM (no dentro de un contenedor), porque
#  necesita hablar con `minero-azul` y `minero-rojo` en paralelo mediante
#  `docker compose exec`. Pensado para proyectarse en pantalla mientras el
#  instructor narra cada paso al aula.
#
#  Uso:
#      ./scripts/fork-demo.sh <comando>
#
#  Comandos:
#      estado       Muestra tip y chaintips de ambos mineros
#      prep         Crea/carga el wallet 'lab' en ambos mineros
#      partition    setnetworkactive false en ambos (los aísla de todo)
#      paralelo     Mina 5 bloques en azul y 3 en rojo
#      reconectar   setnetworkactive true en ambos → dispara la reorg
#      all          Secuencia completa con pausas entre pasos
#
#  Prerequisito: los alumnos ya han propagado algunas tx por la red antes
#  de que se ejecute `partition`, para que esas tx entren en el bloque
#  perdedor y luego se vean "resucitar" tras la reorg.
# =============================================================================
set -euo pipefail

AZUL="minero-azul"
ROJO="minero-rojo"
WALLET="lab"

cli() {
    local node="$1"; shift
    docker compose exec -T "$node" bitcoin-cli -rpcwallet="$WALLET" "$@"
}

cli_nowallet() {
    local node="$1"; shift
    docker compose exec -T "$node" bitcoin-cli "$@"
}

ensure_wallet() {
    local node="$1"
    if cli_nowallet "$node" listwallets | grep -q "\"$WALLET\""; then
        return
    fi
    if cli_nowallet "$node" listwalletdir \
            | jq -e ".wallets[] | select(.name == \"$WALLET\")" >/dev/null 2>&1; then
        cli_nowallet "$node" loadwallet "$WALLET" >/dev/null
    else
        cli_nowallet "$node" createwallet "$WALLET" >/dev/null
    fi
}

show_state() {
    local node="$1"
    echo "== $node =="
    cli_nowallet "$node" getblockchaininfo \
        | jq '{chain, blocks, bestblockhash, networkactive}'
    cli_nowallet "$node" getchaintips
}

case "${1:-help}" in
    estado)
        show_state "$AZUL"
        show_state "$ROJO"
        ;;
    prep)
        echo ">> Asegurando wallet '$WALLET' en ambos mineros..."
        ensure_wallet "$AZUL"
        ensure_wallet "$ROJO"
        echo "   listo."
        ;;
    partition)
        echo ">> Aislando ambos mineros de la red (setnetworkactive false)..."
        cli_nowallet "$AZUL" setnetworkactive false >/dev/null
        cli_nowallet "$ROJO" setnetworkactive false >/dev/null
        echo "   azul y rojo viven ahora en universos separados."
        ;;
    paralelo)
        echo ">> Minando en paralelo: 5 bloques en azul, 3 en rojo"
        ADDR_AZUL=$(cli "$AZUL" getnewaddress)
        ADDR_ROJO=$(cli "$ROJO" getnewaddress)
        echo "   azul mina a $ADDR_AZUL"
        cli "$AZUL" generatetoaddress 5 "$ADDR_AZUL" | jq 'length as $n | "azul: \($n) bloques"'
        echo "   rojo mina a $ADDR_ROJO"
        cli "$ROJO" generatetoaddress 3 "$ADDR_ROJO" | jq 'length as $n | "rojo: \($n) bloques"'
        ;;
    reconectar)
        echo ">> Reconectando — en segundos se ve la reorg"
        cli_nowallet "$AZUL" setnetworkactive true >/dev/null
        cli_nowallet "$ROJO" setnetworkactive true >/dev/null
        ;;
    all)
        "$0" prep
        echo; "$0" estado
        read -r -p $'\n[ENTER] para partir la red... ' _
        "$0" partition
        read -r -p $'\n[ENTER] para minar en paralelo... ' _
        "$0" paralelo
        echo; "$0" estado
        read -r -p $'\n[ENTER] para reconectar y provocar la reorg... ' _
        "$0" reconectar
        sleep 4
        echo; "$0" estado
        ;;
    help|--help|-h|*)
        sed -n '2,26p' "$0" | sed 's/^# \{0,1\}//'
        ;;
esac

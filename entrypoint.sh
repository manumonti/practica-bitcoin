#!/bin/bash
# =============================================================================
#  entrypoint.sh · lab Bitcoin UMA 2026
# -----------------------------------------------------------------------------
#  1. Renderiza /home/alumno/.bitcoin/bitcoin.conf a partir de la plantilla
#     y de las variables de entorno BITCOIN_RPCUSER, BITCOIN_RPCPASSWORD,
#     BITCOIN_RPCALLOW y BITCOIN_PEERS.
#  2. Arranca sshd en foreground.
# =============================================================================
set -euo pipefail

BITCOIN_DIR="/home/alumno/.bitcoin"
CONF="$BITCOIN_DIR/bitcoin.conf"
TEMPLATE="/etc/bitcoin/bitcoin.conf.template"

# ---- Valores por defecto ---------------------------------------------------
: "${BITCOIN_RPCUSER:=alumno}"
: "${BITCOIN_RPCPASSWORD:=bitcoin}"
: "${BITCOIN_RPCALLOW:=172.20.0.0/16}"
: "${BITCOIN_PEERS:=}"

# ---- Generar líneas addnode a partir de BITCOIN_PEERS ----------------------
# BITCOIN_PEERS = "alumno-02,alumno-03,minero-azul,minero-rojo"
#
# El propio contenedor se excluye si aparece listado (bitcoind rechazaría la
# self-connection, pero así evitamos ruido en los logs).
self_host="$(hostname)"
addnodes=""
if [[ -n "${BITCOIN_PEERS}" ]]; then
    IFS=',' read -ra peers <<< "${BITCOIN_PEERS}"
    for p in "${peers[@]}"; do
        p_trim="$(echo "${p}" | tr -d '[:space:]')"
        [[ -z "${p_trim}" ]] && continue
        [[ "${p_trim}" == "${self_host}" ]] && continue
        addnodes+="addnode=${p_trim}:18444"$'\n'
    done
fi
export BITCOIN_ADDNODES="${addnodes%$'\n'}"

export BITCOIN_RPCUSER BITCOIN_RPCPASSWORD BITCOIN_RPCALLOW

# ---- Render del bitcoin.conf (solo si aún no existe) -----------------------
# Si el alumno lo modifica o el contenedor se reinicia, no machacamos su
# trabajo. Para forzar una regeneración, bastaría con borrar el fichero.
mkdir -p "${BITCOIN_DIR}"
if [[ ! -f "${CONF}" ]]; then
    envsubst '${BITCOIN_RPCUSER} ${BITCOIN_RPCPASSWORD} ${BITCOIN_RPCALLOW} ${BITCOIN_ADDNODES}' \
        < "${TEMPLATE}" > "${CONF}"
    chown -R alumno:alumno "${BITCOIN_DIR}"
    chmod 600 "${CONF}"
fi

# ---- Arrancar sshd en foreground -------------------------------------------
exec /usr/sbin/sshd -D -e

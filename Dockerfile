# =============================================================================
#  Imagen base del alumno · Módulo 5 Bitcoin · UMA · 2026
# -----------------------------------------------------------------------------
#  Construye una imagen Ubuntu 24.04 con:
#    · Bitcoin Core (bitcoind + bitcoin-cli)
#    · Herramientas de trabajo: jq, vim, curl, dnsutils, iputils-ping
#    · OpenSSH server (autenticación por contraseña, usuario "alumno" / "bitcoin")
#    · Un entrypoint que genera el bitcoin.conf a partir de variables de entorno
#
#  La misma imagen sirve para contenedores de alumno (alumno-01, alumno-02, ...)
#  y para los contenedores de instructor (minero-azul, minero-rojo).
# =============================================================================

FROM ubuntu:24.04

# ---- Parámetros de build ----------------------------------------------------
ARG BITCOIN_VERSION=28.1
ARG TARGETARCH_BITCOIN=x86_64-linux-gnu

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8

# ---- Paquetes del sistema ---------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates curl gnupg \
        openssh-server \
        vim nano less \
        jq \
        dnsutils iputils-ping net-tools \
        gettext-base \
        tini \
    && rm -rf /var/lib/apt/lists/*

# ---- Instalación de Bitcoin Core -------------------------------------------
RUN set -eux; \
    cd /tmp; \
    curl -fsSL -O "https://bitcoincore.org/bin/bitcoin-core-${BITCOIN_VERSION}/bitcoin-${BITCOIN_VERSION}-${TARGETARCH_BITCOIN}.tar.gz"; \
    tar -xzf "bitcoin-${BITCOIN_VERSION}-${TARGETARCH_BITCOIN}.tar.gz"; \
    install -m 0755 "bitcoin-${BITCOIN_VERSION}/bin/bitcoind"     /usr/local/bin/bitcoind; \
    install -m 0755 "bitcoin-${BITCOIN_VERSION}/bin/bitcoin-cli"  /usr/local/bin/bitcoin-cli; \
    install -m 0755 "bitcoin-${BITCOIN_VERSION}/bin/bitcoin-tx"   /usr/local/bin/bitcoin-tx; \
    rm -rf /tmp/bitcoin-*; \
    bitcoind --version

# ---- Usuario "alumno" -------------------------------------------------------
#   Password: bitcoin
#   Sin sudo: el entorno es efímero, si algo se rompe se reinicia el contenedor.
RUN useradd -m -s /bin/bash alumno \
    && echo 'alumno:bitcoin' | chpasswd \
    && mkdir -p /home/alumno/.bitcoin \
    && chown -R alumno:alumno /home/alumno

# ---- Configuración de SSH ---------------------------------------------------
RUN mkdir -p /var/run/sshd \
    && sed -i 's/^#\?PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config \
    && sed -i 's/^#\?PermitRootLogin .*/PermitRootLogin no/'               /etc/ssh/sshd_config \
    && sed -i 's/^#\?UsePAM .*/UsePAM yes/'                                 /etc/ssh/sshd_config \
    && ssh-keygen -A

# ---- Plantilla del bitcoin.conf y entrypoint --------------------------------
COPY bitcoin.conf.template /etc/bitcoin/bitcoin.conf.template
COPY entrypoint.sh         /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# ---- Helpers del alumno (disponibles en el PATH dentro del contenedor) ------
COPY scripts/send_with_fee.sh /usr/local/bin/send_with_fee.sh
COPY scripts/reset-chain.sh   /usr/local/bin/reset-chain.sh
RUN chmod +x /usr/local/bin/send_with_fee.sh /usr/local/bin/reset-chain.sh

# ---- Puertos expuestos ------------------------------------------------------
#   22     → SSH (mapeado a 61150+k en el host)
#   18443  → RPC regtest (solo accesible desde la red Docker)
#   18444  → P2P regtest (solo accesible desde la red Docker)
#   28332  → ZMQ rawblock (para sesión 4 · LND)
#   28333  → ZMQ rawtx    (para sesión 4 · LND)
EXPOSE 22 18443 18444 28332 28333

# tini gestiona señales y zombis — importante al correr sshd como PID 1
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/entrypoint.sh"]

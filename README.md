# Lab Bitcoin · Sesión 2

Infraestructura Docker para la práctica de laboratorio del Módulo 5
(Curso de Extensión Universitaria en Tecnologías Blockchain · UMA · 2026).

## Ficheros

- **`Dockerfile`** — imagen base Ubuntu 24.04 con Bitcoin Core 28.1, `bitcoin-cli`, `jq`, `sshd` y los helpers del alumno.
- **`bitcoin.conf.template`** — plantilla con variables que el entrypoint sustituye al arrancar.
- **`entrypoint.sh`** — genera el `bitcoin.conf` final y lanza sshd.
- **`docker-compose.yml`** — 4 alumnos (`alumno-01`..`alumno-04`) + 2 mineros (`minero-azul`, `minero-rojo`) en la red `blocknet` (`172.20.0.0/16`).
- **`blocknet.env`** — variables compartidas (peers, RPC user/password, subred) que Compose inyecta en cada servicio vía `env_file`.
- **`scripts/`** — helpers de la práctica:
  - `fork-demo.sh` (host): orquesta la demo de fork/reorg del Bloque 3 con `docker compose exec`.
  - `send_with_fee.sh` (dentro del contenedor): envía BTC con un fee rate explícito y muestra vsize + fee pagado.
  - `reset-chain.sh` (dentro del contenedor): borra `~/.bitcoin/regtest` y rearranca `bitcoind` (plan B si el nodo queda inconsistente).

## Puesta en marcha

```bash
docker compose build
docker compose up -d
docker compose ps
```

## Acceso

```bash
# Desde la VM
ssh alumno@localhost -p 61151     # alumno-01
ssh alumno@localhost -p 61152     # alumno-02
ssh alumno@localhost -p 61153     # alumno-03
ssh alumno@localhost -p 61154     # alumno-04
ssh alumno@localhost -p 61170     # minero-azul
ssh alumno@localhost -p 61171     # minero-rojo
# contraseña: bitcoin
```

Desde fuera de la VM, sustituir `localhost` por la IP/hostname de la VM
(los puertos `61150-61200` deben estar abiertos en el firewall).

Atajo sin SSH, útil para el instructor:

```bash
docker compose exec -u alumno alumno-01 bash
docker compose exec -u alumno minero-azul bash
```

## Comandos típicos

```bash
docker compose build
docker compose up -d
docker compose ps
docker compose logs -f alumno-01
docker compose exec -u alumno alumno-01 bash     # entrar sin ssh
docker compose down -v                 # tirar todo, limpiar volúmenes
```

## Monitorizar logs

Para ver los logs en vivo, abrir una **segunda sesión SSH** al mismo contenedor y lanzar allí:

```bash
tail -f ~/.bitcoin/regtest/debug.log
```

No usamos multiplexores (`screen`, `tmux`) en la práctica: cada ventana
adicional es simplemente otra sesión SSH al mismo puerto.

## Parar y limpiar

```bash
docker compose down          # para los contenedores (datos persisten)
docker compose down -v       # también borra los volúmenes (reset completo)
```

## Escalar a más alumnos

Para pasar de 4 → 15 alumnos basta con replicar el bloque `alumno-0X`
en el compose, actualizando tres cosas:

1. `container_name`, `hostname` y la clave del servicio → `alumno-05`, `alumno-06`…
2. El puerto SSH → `6115N:22` (alumno-k → 61150+k).
3. Añadir el nuevo hostname a `BITCOIN_PEERS` en el bloque `x-common-peers`.

El mismo volumen nombrado (`alumno-0N-data`) debe añadirse a la sección
`volumes:`.

## Notas

- La imagen no arranca `bitcoind` al iniciar; son los alumnos quienes
  lo lanzan durante el Bloque 1 de la práctica. El entrypoint solo
  genera el `bitcoin.conf` y pone en marcha `sshd`.
- Todos los contenedores comparten la misma imagen y la misma lista de
  peers; bitcoind descarta automáticamente los self-peers, así que no
  hay que personalizar la lista por nodo.
- En la red `blocknet`, cada contenedor es resoluble por su nombre
  (`alumno-02`, `minero-rojo`, etc.) gracias al DNS embebido de Docker.

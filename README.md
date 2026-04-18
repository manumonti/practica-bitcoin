# Lab Bitcoin · Sesión 2

Infraestructura Docker para la práctica de laboratorio del Módulo 5
(Curso de Extensión Universitaria en Tecnologías Blockchain · UMA · 2026).

## Ficheros

- **`Dockerfile`** — imagen base Ubuntu 24.04 con Bitcoin Core 28.1, `bitcoin-cli`, `jq`, `sshd` y los helpers del alumno.
- **`bitcoin.conf.template`** — plantilla con variables que el entrypoint sustituye al arrancar.
- **`entrypoint.sh`** — genera el `bitcoin.conf` final y lanza sshd.
- **`docker-compose.yml`** — 16 alumnos (`alumno-01`..`alumno-16`) + 2 mineros (`minero-azul`, `minero-rojo`) en la red `blocknet` (`172.20.0.0/16`).
- **`blocknet.env`** — variables compartidas (peers, RPC user/password, subred) que Compose inyecta en cada servicio vía `env_file`.

## Puesta en marcha

```bash
docker compose build
docker compose up -d
docker compose ps
```

## Acceso

```bash
# Desde la VM — regla general: alumno-k → puerto 61150+k
ssh alumno@localhost -p 61151     # alumno-01
ssh alumno@localhost -p 61152     # alumno-02
# ...
ssh alumno@localhost -p 61166     # alumno-16
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

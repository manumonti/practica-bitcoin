# Práctica de laboratorio · Sesión 2

**Módulo 5 · Bitcoin — Curso de Extensión Universitaria en Tecnologías Blockchain · UMA · 2026**

Duración: 2 horas guiadas paso a paso por el instructor.
Título de trabajo: *"De cero a una red Bitcoin del aula"*.


## Arquitectura de la VM

Una VM Ubuntu (32 vCPU, 64 GB RAM, SSD 300 GB) accesible por SSH con los puertos `61150-61200` expuestos al exterior.

Sobre esa VM el instructor levanta:

- Una red Docker bridge llamada `blocknet` (subred `172.20.0.0/16`) que interconecta todos los contenedores.
- Un contenedor por alumno (`alumno-01`, `alumno-02`, …) con `bitcoind`, `bitcoin-cli`, `jq` y `sshd` preinstalados. Cada contenedor expone su `sshd` en un puerto del rango asignado: alumno *k* → puerto `61150+k`.
- Dos contenedores especiales controlados por el instructor: `minero-azul` y `minero-rojo`. Son idénticos a los de los alumnos pero tienen el rol pedagógico de representar mineros en el bloque de fork.

El `bitcoin.conf` de cada contenedor se genera al arrancar a partir de una plantilla y de la variable de entorno `BITCOIN_PEERS`, que añade una línea `addnode=<peer>:18444` por cada compañero del aula. Así, al iniciar `bitcoind`, se forman conexiones P2P reales entre contenedores: cuando un nodo mina, los demás reciben el bloque por propagación estándar.

Con 15 alumnos + 2 mineros y ~200 MB por contenedor se consumen apenas 4 GB de RAM; `bitcoind` en regtest casi no usa memoria. Para las pruebas iniciales montaremos **4 alumnos + 2 mineros** (6 contenedores); escalar a 15 alumnos es replicar el bloque `alumno-0X` del `docker-compose.yml`.


## Visión general

| Bloque | Minutos | Tema |
|---|---|---|
| 0 | 10 | Arranque y tour del contenedor |
| 1 | 25 | Configuración de `bitcoin.conf` y primer arranque |
| 2 | 30 | La red del aula: propagación P2P en vivo |
| **3** | **20-25** | **Fork y reorganización (opcional si sobra tiempo)** |
| 4 | 30 | La mempool como mercado |
| 5 | 20 | Salto a signet |
| 6 | 5 | Cierre y puente a sesión 4 |


## Bloque 0 · Arranque (10 min)

Los alumnos se conectan por SSH a su contenedor:

```bash
ssh alumno@<vm> -p 6115X
```

Una vez dentro, tour rápido por el sistema de ficheros: dónde está el binario de `bitcoind`, dónde el datadir (`~/.bitcoin/`), dónde los logs (`~/.bitcoin/regtest/debug.log`). Se remarca que `bitcoind` **no está corriendo todavía** — lo arrancarán ellos mismos, a diferencia de la práctica de Nigiri donde el nodo venía arrancado.


## Bloque 1 · Configuración y primer arranque (25 min)

Abrir `~/.bitcoin/bitcoin.conf` con `cat` o `vim`. Lectura guiada línea a línea explicando cada directiva: `regtest=1`, `server=1`, `rpcuser` / `rpcpassword`, `rpcbind=0.0.0.0`, `rpcallowip=172.20.0.0/16`, `txindex=1`, `debug=mempool`, `addnode=alumno-XX:18444`.

Arranque del nodo:

```bash
bitcoind -daemon
bitcoin-cli getblockchaininfo
bitcoin-cli getnetworkinfo
```

Para ver los logs en directo, se explica a los alumnos que pueden **abrir otra terminal y conectarse por SSH al mismo contenedor** (mismo `ssh alumno@<vm> -p 6115X`) y allí ejecutar:

```bash
tail -f ~/.bitcoin/regtest/debug.log
```

Así trabajan con dos ventanas: una para comandos, otra observando los logs. Cada ventana adicional es simplemente otra sesión SSH al mismo contenedor — no usamos multiplexores (`screen`, `tmux`) para mantener el flujo lo más simple posible.

Micro-ejercicio de diagnóstico: pedir que cambien `rpcpassword` en el fichero y reinicien `bitcoind`. La `bitcoin-cli` dejará de funcionar con un `401 Unauthorized`. Aprenden a leer el error, restauran la contraseña original, reinician y vuelven al verde.


## Bloque 2 · La red del aula (30 min)

Cada alumno ejecuta `bitcoin-cli getpeerinfo` y descubre que ya está conectado con varios compañeros. Se explora qué información expone un peer: versión, IP, bloques en común, latencia, dirección de conexión, si es inbound u outbound.

Antes de poder generar direcciones o minar, cada alumno necesita crear un *wallet* — Bitcoin Core 28 no lo hace automáticamente:

```bash
bitcoin-cli createwallet "lab"
bitcoin-cli listwallets
```

A partir de aquí, todos los comandos de wallet (`getnewaddress`, `getbalance`, `sendtoaddress`, …) operan sobre ese wallet por defecto. Si se reinicia el contenedor, el wallet persiste en el volumen; basta con `bitcoin-cli loadwallet "lab"` para volver a usarlo.

Un alumno voluntario (o el instructor) genera la primera dirección de minado y mina 10 bloques:

```bash
ADDR=$(bitcoin-cli getnewaddress)
bitcoin-cli generatetoaddress 10 $ADDR
```

Los demás lanzan `bitcoin-cli getblockcount` y ven subir el contador en tiempo real. Esa propagación es la experiencia que ninguna slide puede transmitir igual.

Después, cada alumno mina 101 bloques a una dirección propia para activar la maduración de coinbase y tener saldo gastable. Comprueban con `getbalance` y observan que los 50 BTC del primer bloque siguen sin ser gastables hasta pasar los 100 bloques de maduración.


## Bloque 3 · Fork y reorganización (20-25 min · opcional)

**Objetivo**: que los alumnos vean en directo qué significa "la cadena con más trabajo gana", cómo se produce una reorg, y por qué las confirmaciones son probabilísticas.

El bloque es opcional porque requiere que el tiempo acompañe, pero es el momento más visceral de toda la práctica si sale bien.

### Setup previo

Los contenedores `minero-azul` y `minero-rojo` están conectados a la red del aula desde el principio, igual que cualquier otro nodo. Para esta demo el instructor los controla directamente por `docker exec` o por SSH.

Conviene llevar preparado un script `fork-demo.sh` con las llamadas encadenadas — ejecutarlas a mano en vivo es frágil.

### Estado inicial (2 min)

Todos los contenedores tienen el mismo tip. Se comprueba proyectando el resultado en pantalla:

```bash
bitcoin-cli getbestblockhash
bitcoin-cli getchaintips
```

Se carga adrede la mempool con un par de transacciones desde los contenedores de alumnos:

```bash
bitcoin-cli sendtoaddress <alguna_dir> 0.5
bitcoin-cli sendtoaddress <otra_dir> 0.25
```

### Paso 1 · Partición (2 min)

El instructor aísla los dos mineros de la red del aula y entre sí:

```bash
# en minero-azul
bitcoin-cli setnetworkactive false

# en minero-rojo
bitcoin-cli setnetworkactive false
```

`setnetworkactive false` desactiva completamente el networking P2P sin matar el proceso. Los mineros siguen operativos pero están en universos separados. Los alumnos no perciben nada distinto.

### Paso 2 · Minado paralelo en ambos universos (5 min)

```bash
# en minero-azul
bitcoin-cli generatetoaddress 5 $(bitcoin-cli getnewaddress)

# en minero-rojo — este va a perder, pero eso aún no lo sabe
bitcoin-cli generatetoaddress 3 $(bitcoin-cli getnewaddress)
```

Crucial: asegurarse de que `minero-rojo` incluye en sus bloques alguna de las transacciones que están en la mempool, para que luego se vean "resucitar". Esto se consigue minando desde un nodo que tenga esas tx en su mempool (los alumnos propagaron las tx a la red antes del aislamiento, así que ambos mineros las tienen).

Pregunta abierta al aula: *"Ambos mineros creen que su cadena es la buena. Ninguno sabe que el otro existe. ¿Cuál es la cadena 'correcta' ahora mismo?"* Aquí se introduce la regla de "heaviest chain" y por qué la verdad en Bitcoin es siempre provisional.

### Paso 3 · Reconexión (2 min)

```bash
# en ambos mineros
bitcoin-cli setnetworkactive true
```

En cuestión de segundos ambos nodos intercambian headers con la red, descubren que hay dos cadenas candidatas partiendo del mismo ancestro común, y aplican la regla de mayor trabajo acumulado. Como azul tiene 5 bloques y rojo solo 3, gana azul.

### Paso 4 · Observación de la reorg (5 min)

Los alumnos lanzan en sus contenedores:

```bash
bitcoin-cli getbestblockhash    # ahora apunta al tip de azul, aunque antes pudo estar apuntando a rojo
bitcoin-cli getchaintips
```

La salida de `getchaintips` es la vista estrella:

```json
[
  { "height": 116, "hash": "...", "branchlen": 0, "status": "active" },
  { "height": 114, "hash": "...", "branchlen": 3, "status": "valid-fork" }
]
```

La rama perdedora no desaparece del nodo: queda marcada como `valid-fork`. Son bloques perfectamente válidos que simplemente no forman parte de la cadena principal.

### Paso 5 · Las transacciones resucitadas (3-5 min)

El remate. Las tx que estaban confirmadas en los bloques del bando rojo **vuelven a la mempool** de todos los nodos, porque han dejado de estar incluidas en la cadena principal:

```bash
bitcoin-cli getmempoolinfo
bitcoin-cli getrawmempool
```

Momento para el aprendizaje clave: "confirmación" significa "incluida en un bloque de la cadena principal **ahora mismo**". Ese estado puede cambiar. Por eso los intercambios y los comercios de alto valor esperan **6 confirmaciones o más** — no porque una reorg sea imposible, sino porque una reorg de 6 bloques es estadísticamente improbable en una red con hash rate global.

Conexión directa con la slide *Confirmaciones y doble gasto* del Módulo 1 y con el concepto de ataque del 51%: lo que acaban de ver es exactamente la mecánica de ese ataque, solo que a mansalva y con intención.

### Detalles de operativa

Para que la demo salga limpia:

- Un par de alumnos voluntarios pueden "ser" azul y rojo, ejecutando ellos los `generatetoaddress` y `setnetworkactive` bajo la dirección del instructor. Hace la narrativa más teatral ("equipo azul vs equipo rojo") sin complicar el setup.
- Los alumnos mantienen una **segunda sesión SSH** abierta al mismo contenedor con un `watch -n 1 'bitcoin-cli getblockcount && bitcoin-cli getbestblockhash | head -c 16'` para ver la altura actualizándose, incluido el salto hacia atrás en los nodos que reorganizan.
- Si el instructor quiere un efecto aún más dramático, puede mantener la partición más tiempo y minar más bloques para generar una reorg profunda (p. ej. 10 vs 6). En producción eso sería catastrófico; en regtest es didáctico.


## Bloque 4 · Mempool como mercado (30 min)

Todos los alumnos disparan transacciones simultáneamente entre ellos con distintos fee rates usando un helper `send_with_fee.sh`:

```bash
bitcoin-cli settxfee 0.00005         # o
bitcoin-cli -named sendtoaddress address=$DEST amount=0.1 fee_rate=25
```

Observan la mempool llenándose:

```bash
bitcoin-cli getmempoolinfo
bitcoin-cli getrawmempool true       # orden por fee rate
bitcoin-cli getmempoolentry <txid>   # ancestros, descendientes, fees agregados
```

Después, un alumno mina un bloque seleccionando a mano qué transacciones entran, usando `generateblock`:

```bash
bitcoin-cli generateblock <addr> '["<txid1>","<txid2>"]'
```

Los demás ven cómo esas transacciones desaparecen de sus mempools mientras las no seleccionadas quedan esperando. Esto materializa la idea de que un minero es un *seleccionador de transacciones*, no solo un buscador de nonces.


## Bloque 5 · Salto a signet (20 min)

Cambio de `bitcoin.conf`: reemplazar `regtest=1` por `signet=1`. Reiniciar `bitcoind` y observar cómo se sincroniza una cadena *real* — signet pesa poco y tarda pocos minutos.

**Nota sobre los `addnode` del aula**: las líneas `addnode=alumno-XX:18444` que generó el entrypoint apuntan al puerto P2P de **regtest** (18444). En signet el puerto P2P es **38333**, así que esas directivas quedan inertes al cambiar de red — no molestan, pero tampoco conectan. `bitcoind` descubre por sí mismo peers públicos de signet vía DNS seeds, que es justo lo que queremos para ver una red *real*. Si se quisiera también que los contenedores del aula se vieran entre sí en signet, habría que añadir a mano `addnode=alumno-XX:38333` o regenerar la plantilla con ese puerto.

```bash
bitcoin-cli getblockchaininfo
bitcoin-cli getpeerinfo   # ahora aparecen IPs reales de internet
bitcoin-cli getchaintips
```

Los alumnos reciben sats desde el [signet faucet](https://signetfaucet.com/) y se los envían entre ellos. Es la misma `bitcoin-cli`, la misma `bitcoin.conf`, el mismo flujo — pero la red es pública.

Cierre conceptual: el software es el mismo, el protocolo es el mismo, solo cambia el conjunto de nodos y las reglas del consenso.


## Bloque 6 · Cierre (5 min)

Recapitulación rápida: qué montaron, qué ficheros tocaron, qué comandos aprendieron. Anuncio de que en **sesión 4** la misma infraestructura servirá para añadir un nodo Lightning encima: el `bitcoind` regtest que acaban de configurar es exactamente el backend que usará LND.


## Continuidad con sesión 4

La imagen Docker de la sesión 2 se ampliará en sesión 4 con `lnd` y algún helper. El `bitcoin.conf` ya queda preparado con los campos que LND necesita: `server=1`, `zmqpubrawblock`, `zmqpubrawtx`, credenciales RPC. Los alumnos arrancarán `lnd` apuntando a su `bitcoind` local, abrirán canales entre ellos aprovechando que todos los nodos ya están conectados en la misma red Docker, y la práctica fluye sin tener que reinstalar nada.


## Artefactos de la práctica

### Ya construidos (raíz del repo)

- **`Dockerfile`** — imagen Ubuntu 24.04 + Bitcoin Core 28.1 + `bitcoin-cli`, `jq`, `sshd` y los helpers del alumno (`send_with_fee.sh`, `reset-chain.sh`) en el `PATH`.
- **`bitcoin.conf.template`** — plantilla con variables (`BITCOIN_RPCUSER`, `BITCOIN_RPCPASSWORD`, `BITCOIN_RPCALLOW`, `BITCOIN_ADDNODES`) y `fallbackfee=0.0002` para que `sendtoaddress` funcione en regtest.
- **`entrypoint.sh`** — renderiza el `bitcoin.conf` al arrancar el contenedor y lanza `sshd`.
- **`docker-compose.yml`** — 4 alumnos + 2 mineros en la red `blocknet` (subred `172.20.0.0/16`), con puertos SSH 61151-61154, 61170 (azul) y 61171 (rojo).
- **`blocknet.env`** — variables compartidas (peers, RPC, subred) inyectadas vía `env_file`.
- **`scripts/fork-demo.sh`** — orquesta la demo del Bloque 3 desde el host.
- **`scripts/send_with_fee.sh`** — envío de BTC con fee rate explícito (Bloque 4).
- **`scripts/reset-chain.sh`** — borra el regtest local y rearranca `bitcoind` (plan B).
- **`README.md`** con instrucciones de puesta en marcha, acceso SSH, logs y cómo escalar a 15 alumnos.

### Pendientes

- Guion paso a paso para los alumnos en PDF o web (un handout de 4-6 páginas).
- Ampliar el `docker-compose.yml` de 4 a 15 alumnos (o añadir un generador `gen-compose.sh`).

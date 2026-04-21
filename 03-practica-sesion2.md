# Práctica de laboratorio · Sesión 2

## Arquitectura de la VM

Se encuentra desplegada una VM Ubuntu accesible por SSH con los puertos `61150-61200` expuestos al exterior.

Sobre esa VM, se encuentra levantado:

- Una red Docker bridge llamada `blocknet` (subred `172.20.0.0/16`) que interconecta todos los contenedores.
- Un contenedor por alumno (`alumno-01`, `alumno-02`, …) con `bitcoind` y `bitcoin-cli` preinstalados. Cada contenedor expone su SSH en un puerto del rango asignado: alumno *k* → puerto `61150+k`.
- Dos contenedores especiales: `minero-azul` y `minero-rojo`. Son idénticos a los de los alumnos pero tienen el rol pedagógico de representar mineros en el bloque de fork.

El `bitcoin.conf` de cada contenedor se genera al arrancar a partir de una plantilla y de la variable de entorno `BITCOIN_PEERS`, que añade una línea `addnode=<peer>:18444` por cada compañero del aula. Así, al iniciar `bitcoind`, se forman conexiones P2P reales entre contenedores: cuando un nodo mina, los demás reciben el bloque por propagación estándar.

## Paso 0. Arranque

Conectar por SSH al contenedor asignado a cada alumno.

```bash
ssh alumno@<vm> -p 6115X
```

Comprueba que bitcoind está instalado:

```bash
bitcoind --version
bitcoin-cli --version
```

Observa que hay una carpeta llamada `.bitcoin` en home. Mira su contenido:

```bash
cd /home/alumno
ls -la
```

## Sección 1. Configuración y primer arranque

Abrir `/home/alumno/.bitcoin/bitcoin.conf` con `cat` o `nano`, o `vim`. Observa las opciones de configuración.

Arranque del nodo:

```bash
bitcoind -daemon
bitcoin-cli getblockchaininfo
```

Abre otra sesión SSH en una terminal diferente, y deja abierto los logs:

```bash
tail -f ~/.bitcoin/regtest/debug.log
```

Esperamos a que nuestros compañeros inicien sus nodos.

## Sección 2. La red del aula

Ejecuta el siguiente comando y mira si ya hay conexiones con compañeros.

```bash
# Observa cuantas conexiones activas hay
bitcoin-cli getnetworkinfo
```

Explora qué información expone un peer: versión, IP, bloques en común, latencia, dirección de conexión, si es inbound u outbound.

```bash
bitcoin-cli getpeerinfo
```

Ahora vamos a generar una wallet en nuestro nodo:

```bash
bitcoin-cli createwallet "wallet"
bitcoin-cli listwallets
```

> **Nota:** A partir de aquí, todos los comandos de wallet (`getnewaddress`, `getbalance`, `sendtoaddress`, …) operan sobre ese wallet por defecto.
> Si se reinicia el contenedor, el wallet persiste en el volumen; basta con `bitcoin-cli loadwallet "wallet"` para volver a usarlo.

Genera una primera address de esta wallet:

```bash
bitcoin-cli getnewaddress "alumnoaddr"
```

> ¿Qué tipo de address es esta?

Cada uno sube a https://dontpad.com/bitcoinuma su address.

Si queremos generar otro tipo de address (no publicar esta address para evitar confusión).

```bash
bitcoin-cli getnewaddress "alumnoaddr2" bech32m
```

**Solo una persona** mina los 10 primeros bloques.

```bash
bitcoin-cli generatetoaddress 10 <addr>
```

> Pregunta: ¿qué hace este comando? ¿sería posible ejecutar este comando en mainnet?

Ejecuta el comando para ver cuantos bloques tiene nuestra blockchain:

```bash
bitcoin-cli getblockcount
```

Ahora podemos consultar su saldo:

```bash
bitcoin-cli getreceivedbyaddress bcrt1qpw073edqn90t3rjehmpt2ss5alh9nh465ktyg2

# alternativamente
bitcoin-cli getbalance
```

> Pregunta: Si hay una address que ha minado 10 bloques, deberá haber recibido la recompensa de esos 10 bloques. ¿Es así? ¿Por qué?

Minamos bloques por turnos (de 10 en 10, hasta 100 bloques) y observamos que el primer address ya tiene balance en el bloque 101.
Es importante que todo el mundo mine para tener balance.

```bash
bitcoin-cli generatetoaddress 10 <addr>
```

Finalmente, para que todo el mundo tenga balance, minamos 1000 bloques.

```bash
bitcoin-cli generatetoaddress 1000 <addr>
```

## Sección 4. Transacciones

Vemos que la mempool se encuentra vacía:

```bash
bitcoin-cli getmempoolinfo
bitcoin-cli getrawmempool
```

Se carga adrede la mempool con un par de transacciones desde los contenedores de alumnos
Hacer transacción a las address de otros alumnos.
Importante que sea una cantidad de menos de 1 BTC para poder identificarlo mejor el balance.

```bash
bitcoin-cli sendtoaddress <alguna_dir> 0.5
```

> Pregunta: Consultamos el balance de nuestra wallet. ¿Ha recibido algo? ¿Por qué?

Consultamos el estado de la mempool:

```bash
bitcoin-cli getmempoolinfo
bitcoin-cli getrawmempool
```

Alguien mina 6 bloques para hacer efectivas las transaccioines:

```bash
bitcoin-cli generatetoaddress 6 <addr>
```

Comprobamos que la mempool está vacía y que el balance ha aumentado (si te han hecho una transacción).

```bash
bitcoin-cli getmempoolinfo
bitcoin-cli getrawmempool
bitcoin-cli getbalance
```

## Sección 5. Fork y reorganización

Vamos a experimentar con el concepto de fork y reorganización de la cadena: "la cadena con más trabajo gana".

### Setup previo

Esto no es trabajo realizado por el alumno, si no que se mostrará en el proyector.

Los contenedores `minero-azul` y `minero-rojo` están conectados a la red del aula desde el principio, igual que cualquier otro nodo.

### Estado inicial

Todos los contenedores tienen el mismo número de bloques:

```bash
bitcoin-cli getchaintips
```

Cargamos en la mempool algunas transacciones:

```bash
bitcoin-cli sendtoaddress <alguna_dir> 0.5
bitcoin-cli sendtoaddress <otra_dir> 0.5
```

Ambos mineros deberán de tener las mismas transacciones en la mempool:

```bash
bitcoin-cli getrawmempool
```

### Paso 1 · Partición

El instructor aísla los dos mineros de la red del aula y entre sí:

```bash
# en minero-azul
bitcoin-cli setnetworkactive false

# en minero-rojo
bitcoin-cli setnetworkactive false
```

`setnetworkactive false` desactiva completamente el networking P2P sin matar el proceso.
Los mineros siguen operativos pero están en universos separados.

### Paso 2 · Transacciones distintas en cada minero

Ahora que las mempools de `minero-azul` y `minero-rojo` están incomunicadas, lanzamos una transacción diferente en cada uno. Así cada bloque que mine a continuación incluirá una tx que **solo existe en su universo**.

```bash
# en minero-azul
bitcoin-cli sendtoaddress <addr_alumno_A> 0.1

# en minero-rojo
bitcoin-cli sendtoaddress <addr_alumno_B> 0.2
```

Comprobamos que cada minero ve en su mempool únicamente su propia tx:

```bash
bitcoin-cli getrawmempool
```

> Pregunta: Si ahora mismo le preguntamos a un alumno, ¿verá estas transacciones en su mempool? ¿Por qué?

### Paso 3 · Minado paralelo en ambos universos

```bash
# en minero-azul
bitcoin-cli generatetoaddress 5 $(bitcoin-cli getnewaddress)

# en minero-rojo — este va a perder, pero eso aún no lo sabe
bitcoin-cli generatetoaddress 3 $(bitcoin-cli getnewaddress)
```

> Pregunta *"Ambos mineros creen que su cadena es la buena. Ninguno sabe que el otro existe. ¿Cuál es la cadena 'correcta' ahora mismo?"*
> Hay dos chains ahora mismo, o lo que es lo mismo, un fork.

Se puede ver que el número de bloques no es el mismo:

```bash
bitcoin-cli getchaintips
```

### Paso 4 · Reconexión

```bash
# en ambos mineros
bitcoin-cli setnetworkactive true
```

En cuestión de segundos ambos nodos intercambian headers con la red, descubren que hay dos cadenas candidatas partiendo del mismo ancestro común, y aplican la regla de mayor trabajo acumulado. Como azul tiene 5 bloques y rojo solo 3, gana azul.

### Paso 5 · Observación de la reorg

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

> Pregunta: ¿qué pasa con las transacciones de la rama que ha perdido?

### Paso 6 · Las transacciones resucitadas

Las tx que estaban confirmadas en los bloques del bando rojo **vuelven a la mempool** del nodo rojo.

```bash
bitcoin-cli getmempoolinfo
bitcoin-cli getrawmempool
```

Momento para el aprendizaje clave: "confirmación" significa "incluida en un bloque de la cadena principal **ahora mismo**". Ese estado puede cambiar. Por eso los intercambios y los comercios de alto valor esperan **6 confirmaciones o más** — no porque una reorg sea imposible, sino porque una reorg de 6 bloques es estadísticamente improbable en una red con hash rate global.

## Sección 6 - Mempool como mercado

Todos los alumnos disparan transacciones simultáneamente entre ellos con distintos fee rates:

```bash
bitcoin-cli -named sendtoaddress address=<addr> amount=0.1 fee_rate=25
```

Observan la mempool llenándose:

```bash
bitcoin-cli getmempoolinfo
bitcoin-cli getrawmempool true       # orden por fee rate
```

Después, un alumno mina un bloque seleccionando a mano qué transacciones entran, usando `generateblock`:

```bash
bitcoin-cli generateblock <addr> '["<txid1>","<txid2>"]'
```

Los demás ven cómo esas transacciones desaparecen de sus mempools mientras las no seleccionadas quedan esperando. Esto materializa la idea de que un minero es un *seleccionador de transacciones*, no solo un buscador de nonces.

## Sección 7 · Salto a signet

Paramos el bitcoind:

```bash
bitcoin-cli stop
```


Cambio de `bitcoin.conf`: reemplazar `regtest=1` por `signet=1`. Reiniciar `bitcoind` y observar cómo se sincroniza una cadena *real* — signet pesa poco y tarda pocos minutos.

```bash
bitcoind -daemon
```

```bash
bitcoin-cli getblockchaininfo
bitcoin-cli getpeerinfo   # ahora aparecen IPs reales de internet
bitcoin-cli getchaintips
```

Se puede crear una nueva wallet y address y pedir sats desde el [signet faucet](https://signetfaucet.com/).

```bash
bitcoin-cli createwallet "wallet"
bitcoin-cli getnewaddress "alumnoaddr"
```

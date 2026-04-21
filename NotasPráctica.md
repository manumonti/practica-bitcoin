# Notas para la sesión

Qué nos dice el prefijo de la address?

bcrt1q8ndvn6042uldnskg5k2stky7735c4mgj6mrngp

Es una dirección P2WPKH (Pay to Witness Public Key Hash)
bcrt: es una dirección de regtest
1: es un separador
q: SegWit v0, formato Bech32

Otra address generada con bech32m

bitcoin-cli getnewaddress "alumnoaddr2" bech32m

bcrt1p2jtns657jldmy52qx4alnq3d3gcgftn6v28t0j3n74sktvr6eqsq34cqef

p: SegWit v1, Taproot.

Es una dirección P2TR (Pay To TapRoot)

Taproot es una actualización de Bitcoin SegWit v1 que introduce firmas Schnorr con la que se gana privacidad y abarata fees.

# URL para compartir addresses

https://dontpad.com/bitcoinuma

# Comandos útiles

bitcoin-cli getaddressesbylabel "alumnoaddr"

# Comandos SSH
minero-rojo: ssh alumno@localhost -p 61170
minero-azul: ssh alumno@localhost -p 61171
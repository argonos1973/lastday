# Puntería de los bots con fusil

Los bots conservan la dispersión, el retroceso, la respiración, la munición
y la balística del arma. La corrección añade el error al colocar la mira que
un jugador ya tiene al manejarla: el centro del torso deja de ser una
coordenada exacta actualizada en cada tick.

## Comportamiento

- La mira usa observaciones breves del objetivo: aproximadamente cada
  0,16 s de día y cada 0,36 s en oscuridad. Un cambio de dirección puede
  adelantarse a la siguiente observación.
- El error de apuntado aumenta con distancia, oscuridad, movimiento del
  tirador y agotamiento. Agacharse o tumbarse ayuda, pero contener la
  respiración no elimina el error de reconocer y seguir el blanco.
- Antorchas, linternas encendidas y fogatas próximas ayudan a distinguir
  al objetivo. Las fogatas apagadas no cuentan.
- El alcance visual sigue aplicándose después de adquirir un enemigo.
  Una línea geométrica libre de paredes no equivale a poder verlo de noche.
  Oírlo puede conservar una pista, pero no actualiza su posición como si
  estuviera a la vista.
- Cada bala pendiente de una ráfaga vuelve a comprobar cobertura y
  visibilidad antes de consumir munición o energía. Si el objetivo ha muerto
  o el bot acaba de aceptar una tregua con él, no sale otra bala. Esto no
  modifica la trayectoria de un proyectil que ya está en vuelo.
- La vigilancia de azoteas también respeta la visibilidad nocturna.

No se decide el daño mediante un porcentaje de éxito. La dirección estimada,
el retroceso, la respiración y la dispersión producen una trayectoria;
`RifleProjectile` resuelve su intersección con cobertura y actores.

El comportamiento vive en `SurvivorBotManager.gd`, en particular
`_bot_rifle_aim_estimate`, `_bot_aim_tick`, `_bot_within_aim_sight` y la
revalidación de `_bot_fire_rifle_round`. El registro limitado de disparos
incluye incertidumbre angular, oscuridad y edad de la observación.

## Comprobación reproducible

`tools/debug/BotAimRecoilRegression.gd` compara 420 muestras por caso,
con semilla fija, usando la intersección de cápsula del propio
`RifleProjectile`. Se concede respiración perfectamente contenida y
retroceso recuperado para comprobar incluso el caso más favorable al bot.
Esta medición aísla el apuntado: no representa un porcentaje garantizado
de impactos en una partida, ni simula una ráfaga completa en movimiento.

| Caso | Intersecciones |
|---|---:|
| Referencia con seguimiento exacto, M4 a 25 m | 420/420 |
| M4 a 25 m, día, blanco quieto | 386/420 (91,9 %) |
| M4 a 25 m, noche, blanco sin luz | 134/420 (31,9 %) |
| M4 a 25 m, noche, blanco con antorcha | 295/420 (70,2 %) |
| M4 a 25 m, noche, blanco corriendo | 99/420 (23,6 %) |
| M4 a 10 m, noche, blanco quieto | 420/420 |
| M4 a 40 m, día | 216/420 (51,4 %) |
| M4 a 25 m, tirador moviéndose | 262/420 (62,4 %) |
| M4 a 20 m, noche, blanco agachado | 171/420 (40,7 %) |
| Francotirador tumbado a 50 m, día | 295/420 (70,2 %) |
| Francotirador tumbado a 50 m, noche | 50/420 (11,9 %) |

El mismo script comprueba proyectiles físicos que causan daño o fallan,
reacción a movimiento brusco, pérdida de visión, reacquisición, fogatas
apagadas, cobertura y los callbacks reales de una ráfaga interrumpida
al apagarse la luz del objetivo. Se mantienen las comprobaciones de
retroceso, energía y dispersión mecánica compartida con el jugador.

La corrección es autoritativa del servidor. Actualizar únicamente el cliente
conectado a un servidor antiguo no cambia la puntería de sus bots.

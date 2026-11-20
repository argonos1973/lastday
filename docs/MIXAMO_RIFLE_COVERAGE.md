# Cobertura de rifle/M4 y verificación de rendimiento

La selección se descargó de Mixamo y se integró sobre los personajes
existentes. Los cambios están locales sobre `71b2121`, sin commit ni
publicación. El cliente macOS local está regenerado con estos cambios.

## Movimientos conectados

| Grupo | Cobertura |
|---|---|
| De pie | Reposo y apuntado, marcha y carrera en ocho direcciones. |
| Agachado | Reposo, apuntado y marcha en ocho direcciones. |
| Giros | Izquierda/derecha de pie, agachado y tumbado. |
| Posturas | De pie/agachado, de pie/arrodillado y arrodillado/tumbado donde el estado del controlador permite esas transiciones. |
| Salto | Impulso, fase aérea y aterrizaje con rifle. |
| Disparo | Clip de pie existente y variantes agachada/tumbada. |
| Recarga | De pie, agachado/arrodillado y tumbado; siempre 2,2 s. |

La marcha usa el desplazamiento relativo al cuerpo. Los personajes remotos
resuelven las ocho direcciones aunque el servidor envíe solamente `walk`,
`run` o `sneak`; no consultan el teclado local. Se mantiene la animación de
marcha mientras termina la interpolación de una parada.

El M4 se transporta cruzado y con el cañón ligeramente hacia abajo al correr.
La selección de clip y el ajuste del arma comparten `_rifle_running`: el
jugador usa su estado de sprint y los personajes remotos usan el movimiento
recibido por red. La pose automática de cámara no puede devolver el arma al
hombro durante esa carrera. La regresión gráfica comprueba la orientación
real del cañón y ambas manos en las ocho direcciones, en local y remoto.

Las transiciones de postura son cosméticas, de 0,35 s, y ceden ante movimiento,
acciones, apuntado, escalada y dolor. No bloquean controles ni cambian cápsulas.
Impulso y aterrizaje usan ventanas de 0,20 y 0,18 s; gravedad y caída siguen
en la física existente. Las acciones recibidas por red conservan prioridad.

Las recargas seleccionan la postura tanto en el jugador como en los
personajes remotos. Los bots anuncian la recarga también agachados,
arrodillados y tumbados. El cambio es de presentación: transferencia de
munición, interrupciones y duración se mantienen en las reglas actuales.

## Colocación del arma

M4 y francotirador conservan sus puntos propios de empuñadura, guardamanos,
culata, mira y bocacha. El agarre se aplica después del reproductor mediante
el modificador de esqueleto existente.

La orientación del arma se comprueba contra el modelo dibujado. El giro de
muñeca del clip no puede hacer que el cañón apunte al cuerpo. La vista de mira
del jugador sigue usando su comportamiento propio; la cámara de depuración
no debe desplazar el arma física.

Durante la recarga, `RifleActionGrip.gd` mueve el cargador y mecanismo del
modelo existente y permite que la mano de apoyo abandone el guardamanos.
Se comprueban sus contactos con las piezas reales y su regreso al apoyo.
No se crean otras mallas ni texturas para representar la recarga.

`M4IdleGripRegression -- --directions --actions` lee las matrices de skin
del renderizador: 24 muestras por clip, en actores locales y remotos.
Se repitió con `--sniper`. Resultado:

| Arma | Errores | Máximo de separación en contactos comprobados |
|---|---:|---:|
| M4 / fusil de asalto | 0 | 2,08 mm |
| Francotirador | 0 | 1,81 mm |

La prueba incluye locomoción, giros, posturas, saltos, disparos y las tres
recargas. Los intervalos en que la mano viaja libre entre cargador, mecanismo
y guardamanos no se confunden con un fallo de contacto. `RifleGripRegression`
comprueba también orientación, culata, correa, restauración de dedos y
reconstrucción de equipo.

## Recursos y selección conservada

La biblioteca compartida contiene **65 clips, 65 huesos y ninguna malla o
imagen**, con un tamaño de **5,029 MiB**. Solo se evalúa el clip elegido en el
`AnimationPlayer` existente. La adaptación se guarda por esqueleto compatible;
no se repite por fotograma ni se incorporan otros reproductores permanentes.

La selección y sus IDs están en `assets_src/mixamo/catalog.json`; las
procedencias verificadas están en `assets/animations/mixamo/SOURCES.json`.
`MIXAMO_RIFLE_CANDIDATES.csv` conserva la investigación inicial, no una lista
de clips todos activos.

Se conservan como alternativas descargadas `raise_to_aim`, `lower_from_aim`,
`equip`, `holster`, `fire_stand`, `hit_stand`, `hit_crouch`, `hit_prone`,
`death_stand` y `death_prone`. No sustituyen automáticamente los gestos
existentes. Sacar/guardar y apuntar mantienen su respuesta; dolor y muerte
mantienen sus clips y ventanas ya verificadas. La transición completa de
tumbado a de pie conserva el gesto anterior cuando lo solicita el controlador.

Fuente oficial: [Mixamo](https://www.mixamo.com/).
Familias investigadas:
[Rifle 8-Way Locomotion Pack](https://www.mixamo.com/#/?page=1&query=Rifle%208-Way%20Locomotion%20Pack)
y [Pro Rifle Pack](https://www.mixamo.com/#/?page=1&query=Pro%20Rifle%20Pack).
Los IDs y parámetros concretos, no el nombre de la familia, identifican
las variantes utilizadas.

## Rendimiento

Comparación secuencial y sin otras pruebas simultáneas, en Apple M2 de 8 GB,
Godot 4.7 Compatibility/OpenGL, 1280×720, sin VSync. Cuatro actores con
ropa y armas alternadas M4/francotirador; 120 fotogramas de preparación y
600 muestras por estado. El escenario no genera el mundo ni escribe partidas.

Se compararon el controlador/modificador archivados antes de esta integración
con los actuales, manteniendo los mismos recursos visuales y encuadre.
Se usa tiempo real entre fotogramas; el monitor `TIME_PROCESS` cacheado por
Godot no es un cronómetro independiente por muestra.

| Estado | Media antes / después | p95 antes / después |
|---|---:|---:|
| Reposo | 10,42 / 10,24 ms | 11,74 / 11,64 ms |
| Marcha | 10,14 / 10,28 ms | 11,45 / 11,77 ms |
| Apuntado | 10,45 / 10,34 ms | 11,93 / 11,55 ms |
| Recarga | 10,52 / 10,52 ms | 12,01 / 11,95 ms |

- Llamadas de dibujo: **228 antes y después**.
- Primitivas: **204.758 antes y después**.
- Texturas: **145,54 MiB antes y después**.
- Memoria gráfica: **175,60 MiB antes y después**.
- Memoria estática: **84,65 → 88,81 MiB**, aproximadamente **+4,16 MiB**.

No aparece una regresión sostenida en este escenario. Hay picos aislados
de 68,5 ms antes y 75,8 ms después: la prueba no demuestra ausencia absoluta
de tirones ni garantiza los FPS del mapa completo. Las optimizaciones
anteriores de texturas, materiales y preparación del mundo se conservan.

Los JSON de la comparación están en `build/tmp/motion_profile_before.json`
y `build/tmp/motion_profile_after.json`. `tools/debug/MotionPerformanceProbe.gd`
permite medir el controlador actual o uno archivado con `--player-script=...`;
`--output=...` cambia el informe. La comparación registrada usó el mismo
probe temporal con ambas clases cargadas para igualar su coste de recursos.

## Comandos de verificación

Desde la raíz, con `GODOT=work/godot4.7/Godot.app/Contents/MacOS/Godot`:

```sh
"$GODOT" --headless --path . --check-only --script scripts/Main.gd
"$GODOT" --path . --script tools/debug/M4IdleGripRegression.gd -- --directions --actions
"$GODOT" --path . --script tools/debug/M4IdleGripRegression.gd -- --directions --actions --sniper
"$GODOT" --headless --path . --script tools/debug/RifleGripRegression.gd
"$GODOT" --path . --script tools/debug/PrimitiveCarryPreview.gd
"$GODOT" --path . --script tools/debug/PrimitiveNetworkRegression.gd -- --capture-spear
"$GODOT" --path . --script tools/debug/PredatorFeedbackRegression.gd
"$GODOT" --path . --script tools/debug/MotionPerformanceProbe.gd
```

Las pruebas de skin, imagen, proyectil visible y mezclador requieren ejecución
gráfica. Las comprobaciones funcionales adicionales son
`PrimitiveReleaseRegression`, `PrimitiveCoverRegression`, `PickupAnimRegression`,
`PuppetTorchRegression`, `BackRodRegression`, `RemoteSlideRegression`,
`ShelterCameraWeaponRegression` y `BotGunAmmoRegression` (137 comprobaciones).

## Cliente local

`build/macos/LastDay.app` se exportó después de ejecutar
`tools/stamp_version.sh`, con la biblioteca nativa instalada mediante
`tools/install_native.sh` y firma ad-hoc verificada con
`codesign --verify --deep --strict`.

Sobre el PCK exportado pasan `SurvivalInventoryRegression` y
`PickupAnimRegression`, ambas con cero fallos. La etiqueta sigue siendo
`71b2121`, el HEAD usado por el estampador; el paquete incluye los cambios
del árbol de trabajo aún sin commit. No se modificó la descarga pública
ni el servidor.

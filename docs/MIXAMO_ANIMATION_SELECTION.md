# Animaciones de personaje: integración y verificación

Base de la tarea: `71b2121`, después de la optimización de texturas y entrada
al mundo. Los cambios de esta integración están en el árbol de trabajo.
El cliente macOS local está regenerado y firmado; las pruebas de inventario
y selección de movimientos pasan también dentro del paquete exportado.
La cobertura de armas largas y las mediciones están en
[MIXAMO_RIFLE_COVERAGE.md](MIXAMO_RIFLE_COVERAGE.md).

## Recursos y reproducción

Se descargaron **65 variantes oficiales de Mixamo** usando la sesión Adobe
del usuario, X Bot, FBX Binary, **Without Skin, 30 FPS**, sin reducción de
claves e `In Place` donde lo admite el movimiento. La biblioteca resultante,
`assets/animations/mixamo/character_motions.glb`, ocupa **5,029 MiB** y contiene
65 animaciones, 65 huesos, **cero mallas y cero imágenes**.

- `assets_src/mixamo/catalog.json`: selección y parámetros del catálogo.
- `assets/animations/mixamo/downloads.json`: descargas y comprobaciones.
- `assets/animations/mixamo/SOURCES.json`: procedencia, IDs, ajustes y SHA-256.
- `tools/download_mixamo.py`: descarga reanudable desde la sesión de Chrome;
  el token permanece dentro del navegador.
- `tools/blender/import_mixamo_selection.py`: conversión de los FBX.

Los FBX originales quedan en `assets_src/mixamo`, fuera del escaneo y de la
exportación de Godot mediante `.gdignore`. No hay copias nuevas del personaje
ni texturas asociadas a estos clips.

`CharacterMotionLibrary.gd` adapta las rotaciones al esqueleto del actor y
comparte la biblioteca entre esqueletos compatibles. La clave de compatibilidad
incluye nombres, jerarquía, reposos y ruta del esqueleto. Se eliminan traslaciones,
escalas y huesos sin correspondencia: movimiento, salto, colisión y autoridad
siguen en el controlador. Se conserva un solo `AnimationPlayer`.

## Acciones generales

| Acción | Integración |
|---|---|
| Lanzar | `motion/throw_object`, separado del ataque y de la tala. |
| Cavar con pala | `motion/dig`, con orientación del mango y apoyo de ambas manos sobre el objeto real. |
| Recoger fruta del árbol | `motion/pick_fruit`, conectado a la acción `pick_fruit` de `Main`. Conserva sus 3 segundos y las comprobaciones de alcance/recurso. |
| Herido en reposo / caminando | `motion/injured_idle` y `motion/injured_walk` en los selectores de salud existentes. |
| Comer | `motion/eat_fruit`: captura específica de comer de CMU, adaptada al personaje, con el alimento en la mano derecha. Conserva 2 segundos y cancelación. |
| Recoger objetos del suelo | `motion/pickup_ground`: una sola recogida de Mixamo de 1,4 s antes de entregar o equipar el objeto. Los alimentos pasan después al gesto de comer. |

La recogida usa **Pick Fruit — Picking Fruit From Ground**, ID oficial
`c9cda77e-b96c-11e4-a802-0aaa78deedf9`, revisado sobre el personaje del juego.
Se añade como `assets/animations/ground_pickup.glb`: **99,5 KiB**, 65 huesos,
sin mallas ni imágenes. La fuente, sus ajustes y su SHA-256 están en
`assets/animations/ground_pickup.SOURCES.json`. Se regenera con
`tools/blender/import_ground_pickup.py`; el descargador admite
`--roles pickup_ground`.
Se conserva solo el primer alcance al suelo y la incorporación final:
se eliminan la espera inicial, las otras dos recogidas y la inspección de la
fruta. Después del contacto, el brazo vuelve a una pose de transporte para
que los objetos grandes, como los fusiles, no atraviesen el rostro.

`GroundItemGesture` gestiona solo la representación: mantiene el objeto
concreto en la mano, oculta su visual del suelo al llegar la mano a los
**0,7 s** y restaura los visuales si se cancela. El inventario, la reserva
del servidor, las porciones, la durabilidad y el agotamiento del objeto
siguen siendo responsabilidad de las acciones existentes. Recoger tarda
1,4 s; comer del suelo añade después el tiempo propio del alimento. Una
cancelación antes de terminar la comida devuelve el alimento al suelo.
También se puede comer con la mochila llena.

Jugadores y bots envían fase, identidad del objeto y tiempo transcurrido
mediante el campo de animación existente. Un cliente que llega durante
el gesto entra en la misma fase; las instantáneas repetidas no reinician
la animación. Los bots mantienen su plan y solo detienen la recogida
individual cuando hay una interrupción. El daño pasivo por necesidades
no impide recoger comida; los impactos sí interrumpen.

La comparación aislada contra `1da44eb` usa cuatro personajes, 600 fotogramas
por estado y ejecuciones secuenciales. En reposo: **16,11 → 16,16 ms** de media;
caminando: **15,87 → 16,18 ms**. Se conservan **228 llamadas de dibujo**,
**204.758 primitivas** y **145,87 MiB de texturas**. La memoria estática
aumenta aproximadamente **0,11 MiB**. Son mediciones de esa escena local,
no una medición de FPS del servidor público.

Regresiones: `PickupAnimRegression` (secuencia, cancelación, capacidad,
visuales, bots y biblioteca compartida), `MultiplayerPickupRegression`
(reservas reales y cancelación durante la respuesta del servidor),
`BackpackContentsRegression`, `InventoryFixesRegression`,
`SurvivorBotsAndCombatRegression` y `RifleGripRegression` (agarre al recoger
ambos fusiles y recuperación del equipo tras cancelar).

La preparación de tierra solicita `dig`: la pala usa su clip; las azadas
conservan el gesto anterior, porque su cabeza y agarre no corresponden al de
una pala. Plantar, regar, limpiar y recolectar un bancal siguen diferenciados
por sus acciones y tiempos existentes.

La consulta oficial de Mixamo no devuelve un clip específico de comer.
Se usa la captura **CMU 80_24, “eating”**, recortada a un bocado de dos segundos
y adaptada al esqueleto actual. El ajuste del brazo se hornea al generar el
asset; no añade un solucionador ni una capa permanente durante la partida.
`assets/animations/eat_fruit.glb` ocupa aproximadamente **96 KiB**, sin mallas
ni texturas. Se carga en la misma biblioteca compartida y conserva el alimento
real en la mano derecha. Procedencia, licencia y regeneración:
`assets_src/consumption/README.md`, `tools/blender/import_eating_motion.py`.

El sonido sigue la posición real del clip, tanto en local como en remoto:
el sorbo empieza en **3,30 s** de `Drinking.glb` y el bocado en **0,65 s**
de `eat_fruit`. La subida de la mano permanece silenciosa. Cancelar, morir o
salir del gesto detiene el audio; los avisos repetidos de red no lo reinician.
Beber de una fuente sin botella conserva su acción y sonido propios.
La acción de inventario de los bots dura 1,6 s: su representación entra en
3,15 s del clip de bebida, antes del sorbo y con la transición normal de
0,15 s. Así se ve y se oye el gesto sin cambiar sus tiempos ni reglas del servidor.

## Preparación y suelta

El barrido de `throw_object` sitúa el pico de avance de la mano cerca de
**0,83 s**. La preparación se congela en **0,40 s**; la suelta de arma apuntada
reanuda desde allí a velocidad 1 y conserva `THROW_RELEASE_DELAY = 0,42 s`.
El proyectil sale cerca del momento de extensión del brazo, sin reiniciar
la preparación. Los objetos ordinarios lanzados con G pasan al seguimiento
del gesto al soltarse, conservando la respuesta inmediata existente.

La red distingue `throw_aim` y `throw`. Los bots anuncian su preparación con
`throw`; el cliente resuelve el clip y la extensión del brazo. La simulación
sigue revalidando el lanzamiento, consumiendo un objeto real y conservando
velocidad, cobertura, daño y recuperación autoritativos.

## Revisión de objetos

Se comprobaron jugador local y representación remota en reposo, marcha y
acción, incluyendo cambios de objeto:

- Arco reforzado y la construcción compartida con el arco de madera:
  agarre izquierdo, cuerda tensada, flecha montada según munición y separación
  en el disparo.
- Lanza, lanza de hueso y construcción de palo afilado: asta en la palma,
  dirección de lanzamiento, dedos y brazo durante preparación y extensión.
- Boleadoras, cuchillo y hacha: objeto real y agarre genérico compartido.
- Pala y azada: sentido del mango, escala y punto de sujeción; la pala conserva
  las dos manos en el mango al cavar. También se admiten los tipos reales
  `tool_shovel`, `tool_hammer` y `tool_pickaxe`.
- Caña: conjunto rígido completo, empuñadura medida sobre la pieza del mango,
  ausencia de duplicados, animaciones cargadas al empezar a pescar y
  colocación centrada en la espalda.
- Antorcha: socket propio, llama y luz en la punta, estado remoto persistente
  y limpieza al cambiar de objeto.
- Botella y comida: gesto y objeto en la mano izquierda, restauración del
  objeto de transporte al terminar.

`HeldGripModifier.gd` aplica los ajustes después del reproductor. Los giros
y posiciones de dedos se calculan desde el reposo y se restauran; no se
acumulan entre fotogramas. Los ajustes de pala reutilizan el solucionador
de brazo existente.

## Verificación

`PrimitiveCarryPreview.gd` comprueba construcción, cotas local/remoto y
clips de 12 categorías de objetos. Captura poses reales en
`build/tmp/held_<objeto>_<modo>_<local|remote>/`; incluye el recorrido de
lanzamiento de lanzas y boleadoras. La pala comprueba además el contacto de
la mano de apoyo durante todo el clip. Se puede limitar con
`-- --items=shovel,food`.

`PickupAnimRegression` verifica recogida instantánea, fruta, pala, consumo,
biblioteca compartida, ausencia de traslaciones/escalas en los clips,
salto y cancelación de transiciones cosméticas.

También se ejecutaron las regresiones de suelta, cobertura, red gráfica,
antorcha/consumo remoto, espalda/caña, continuidad de marcha y cámara de
refugio. `PredatorFeedbackRegression` verifica **104 comprobaciones sin
errores funcionales**, con WebSocket real, reacción importada y voz en el
mezclador. Al cerrar esa prueba, Godot GLES3 sigue avisando de cuatro shaders
de partículas sin liberar; el mismo aviso aparece en la captura anterior
`build/tmp/PredatorFeedbackRegression_spear_render.log`.

Los resultados de rendimiento corresponden al escenario aislado de actores
descrito en el informe de rifle. No representan una nueva medición del mundo
completo, del lago ni de la ciudad.

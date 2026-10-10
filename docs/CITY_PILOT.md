# Manzana piloto: ciudad abandonada

Escena independiente: `scenes/city/CityPilot.tscn`.

```sh
work/godot4.7/Godot.app/Contents/MacOS/Godot --path . scenes/city/CityPilot.tscn
```

WASD para caminar, ratón para mirar, F para abrir/cerrar una puerta a menos de 3 m, Esc para liberar el cursor. No inicia Main ni modifica partidas. Cuatro edificios de dos plantas con huecos reales, habitaciones, muebles y escaleras. Los modelos se generan en Blender con `tools/blender/create_city_block.py`; fuentes editables en `outputs/city`, GLB y texturas importadas en `assets/models/environment/city`.

La carga de nodos funciona por distancia (100 m entrada / 135 m salida) y conserva las puertas mientras dura la escena; es una prueba local por edificio. La misma geometría ya está integrada en el mundo real al sur del mapa (ver *Integración en el mundo*), donde las casas permanecen residentes y las puertas van por los RPCs existentes. La rampa de colisión de las escaleras coincide con los peldaños y permite caminar sin salto; en el piloto, el avatar real (`V`) reproduce además el clip de subir escaleras.

Validación:
```sh
work/godot4.7/Godot.app/Contents/MacOS/Godot --headless --path . --import
work/godot4.7/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/debug/CityBlockRegression.gd
```

Pendiente de la integración: loot real en las viviendas (hoy no se genera nada), una prueba en vivo con dos clientes y pulir navegación de animales dentro de la manzana. El caminante de esta escena sigue siendo una cápsula de prueba; el avatar con `V` sí usa el `PlayerController` real.

## Revisión de materiales y escaleras

La carretera usa `road_surface.gdshader` y `Ground038_1K-JPG_Color.jpg`, como Main, con el mismo ancho de 10 m y UV métricas. El anterior `broken_road.glb` ya no se instancia. Las fachadas se reconstruyen en Blender con materiales de cal, ladrillo, madera y pizarra del juego; se han eliminado las placas superpuestas de suciedad y musgo.

El archivo aportado es `outputs/Walking Up The Stairs.fbx` (fuente; `outputs/` no se versiona). `tools/blender/import_stair_animation.py` produce `assets/animations/walking_up_stairs.glb`. `StairAnimation.gd` adapta las rotaciones a cada esqueleto y elimina traslación/escala del origen. El controlador usa el clip al ascender sobre `stair_surface`; mantiene las animaciones existentes al llevar rifle, antorcha o caña. No hay clip de descenso en el archivo aportado.

En el piloto, V alterna la vista en tercera persona con el personaje real. `StairAnimationRegression.gd` comprueba pistas, ausencia de desplazamiento acumulado y selección en escaleras frente a pendientes; `StairAnimationPreview.gd` produce la captura del personaje. La integración de la ciudad en Main y las pruebas entre dos clientes siguen pendientes.

## Integración en el mundo (10 octubre)

`Main._create_map` crea la ciudad en (9, 0, 680), al sur del mapa anterior. El área transitable pasa de X/Z ±500 a X ±500, Z -500…900: 1 × 1,4 km. `MAP_EXTENT` conserva el valor 500 para no multiplicar la generación de vegetación y fauna; se añade una franja de terreno y se amplía el suelo de colisión. No se han ampliado las zonas de aparición de animales.

La calle principal enlaza con el extremo real de la carretera generada (aprox. Z 499,6), con el mismo ancho de 7 m. Se reserva el corredor antes de generar relieve. El cruce sur dispone de un tablero con rampas y barandillas; el agua sigue existiendo bajo el puente y no activa natación sobre el tablero.

Las cuatro casas permanecen cargadas en Main para conservar colisiones, puertas, guardado y estado de red mediante los sistemas existentes. El servidor también crea sus colisiones y puertas, con los modelos ocultos. El streaming por distancia sigue siendo exclusivo del piloto. No se ha añadido loot nuevo a la ciudad ni se ha exportado una aplicación.

Validación adicional: `tools/debug/CityIntegrationRegression.gd` (paso libre, límites, abrigo y puertas del servidor), `tools/debug/CityIntegrationPreview.gd` (vista aislada de conexión con las funciones reales de terreno y carretera, sin modificar partidas). No sustituye una prueba completa con dos clientes.

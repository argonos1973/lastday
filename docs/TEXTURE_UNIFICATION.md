# Unificación de texturas — 20-11-2026

Se han actualizado **170 referencias a imágenes en 34 modelos** para compartir
texturas con contenido SHA-256 y parámetros de importación idénticos.
La unificación no modifica scripts del juego, geometría, UV, esqueletos,
animaciones, materiales, resolución ni compresión de las imágenes.

## Resultado medido

Mismo recorrido de pueblo, río, ciudad y lago, con el renderizador real:
Apple M2, Godot 4.7 Compatibility, 1280×720, escala 100%, mediodía,
`--client-visuals`, ocho segundos para las secuencias de cambios de vista.

| Medida | Antes | Después |
|---|---:|---:|
| Memoria de texturas del renderer | 1.477,36 MiB | 1.260,34 MiB |
| Caminos de textura activos en el informe final | 658 | 485 |
| Fotogramas de más de 100 ms en los 16 escenarios | 21 | 14 |

El ahorro observado es de **217,02 MiB, aproximadamente un 14,7 %** de la
memoria de texturas anterior. Los tiempos de fotograma son una observación de
esta pasada, no una garantía de mejora proporcional de FPS. El pueblo continúa
aproximadamente entre 18 y 23 FPS en esta máquina; sus costes de actualización,
fachadas e hierba no desaparecen al compartir imágenes.

## Assets afectados

- 8 modelos de granito del lago.
- 9 modelos de ciudad: edificios 2/3/4, edificio alto, torre del reloj,
  pavimento, caja de cartón, banco y farola.
- 7 modelos ambientales Quaternius: barril, palé roto, farolas, señal urbana,
  semáforo y dos bolsas de basura.
- 3 recursos de animaciones de pesca.
- 3 modelos de personajes/ropa: personaje vestido, torso de soldado y chaqueta
  verde recogible.
- 2 módulos de ribera.
- Red de camuflaje de la torre y cargador M4.

Solo cambian las entradas `images` de los GLB/glTF: sus referencias apuntan a
una imagen existente compartida mediante URI relativo. Se conservaron todos
los demás campos JSON y, en los GLB, todos los bloques binarios originales.
Se verificó su identidad por SHA-256. Los datos binarios de los glTF tampoco
cambian.

Las copias de imágenes extraídas se conservan como fuentes y por compatibilidad
con otras referencias y generadores. El ahorro medido corresponde a las
texturas cargadas; no se presenta como una reducción equivalente del ZIP.
Una nueva exportación desde Blender puede volver a incrustar imágenes y
reintroducir referencias independientes, por lo que conviene repetir esta
comprobación después de regenerar los modelos.

## Límites deliberados

Se respetaron las diferencias de parámetros de importación, aunque dos
archivos contengan los mismos bytes. No se intercambian mapas que tengan
tratamientos distintos de compresión, normales, mipmaps u otros parámetros.

Dos alias compatibles del análisis, unos **2 MiB** en total, siguen cargándose
mediante rutas construidas por `VillageArchitecture.material`:

- `assets/textures/overgrowth/village_clay_normal.png`
- `assets/textures/overgrowth/village_slate_roughness.png`

Unificar esas llamadas requeriría modificar el código que selecciona las
texturas. Se han conservado para respetar el alcance de esta tarea.

## Validación

- Importación completa de Godot sin errores.
- **34 modelos y 267 superficies:** propiedades de materiales y contenido real
  de texturas idénticos antes y después. Se compararon dimensiones, formato y
  SHA-256 de los datos de imagen, además de las propiedades de los materiales.
- Mismos resultados sobre el **PCK exportado**, ejecutando el comprobador desde
  `LastDay.app/Contents/Resources`, sin disponer allí de los assets sueltos del
  repositorio. El comprobador gráfico de materiales utilizó el controlador de
  audio de reserva al no poder abrir la entrada CoreAudio; esta prueba no
  valida audio.
- Recorrido completo de **16 escenarios**, con capturas e informe de memoria:
  ningún fotograma descartado por ventana oculta.
- `WaterFishRegression`: **0 fallos**.
- `SurvivalInventoryRegression` sobre el paquete: **0 fallos**.
- Cliente macOS regenerado, biblioteca nativa instalada y firma ad-hoc
  verificada.
- SHA-256 de todos los archivos de `scripts/` idéntico al inicio de esta tarea.

`VillageRegression` conserva **3 fallos anteriores** en expectativas de
acabados de cubiertas y fachadas. Se restauraron temporalmente los 34 assets
originales, se reimportaron y se repitió la prueba: fallan exactamente las mismas
tres comprobaciones. Después se restauraron los assets unificados, se verificó
que eran byte a byte los mismos y se reimportaron antes del export definitivo.
No se modificó esa prueba ni el comportamiento de las casas.

## Evidencia y cliente local

- `build/tmp/texture_unification/applied.json`: referencias actualizadas y hashes.
- `build/tmp/texture_unification/materials_before.json`
- `build/tmp/texture_unification/materials_after.json`
- `build/tmp/texture_unification/materials_packaged.json`
- `build/tmp/texture_unification/material_comparison.json`
- `build/tmp/traversal_unified_textures.json` y capturas del mismo prefijo.
- `build/tmp/texture_unification_village_before.log`
- `build/tmp/texture_unification_regressions.log`
- `build/tmp/texture_unification_water.log`
- `build/tmp/texture_unification_packaged_inventory.log`
- `build/macos/LastDay.app`: cliente local actualizado.

El generador temporal de las modificaciones es
`build/tmp/unify_asset_textures.py`; el verificador de materiales es
`build/tmp/TextureUnificationCheck.gd`. Ambos quedan fuera de los scripts del
juego y del paquete.

Los cambios siguen locales, sin commit, push ni publicación. El cliente local
lleva el sello del HEAD actual (`a464ac7`) junto con los cambios locales de
rendimiento y esta unificación; no debe confundirse con la descarga pública
del mismo hash.

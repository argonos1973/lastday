# Auditoría de assets del pueblo — 20-11-2026

Se inspeccionaron los recursos y se midió el cliente sin modificar archivos del
juego. Se añaden este informe y herramientas/resultados temporales en
`build/tmp/`. Se verificó que el SHA-256 del diff de los archivos versionados
coincide exactamente con el del inicio de la auditoría. Los ajustes guardados
de gráficos conservan su fecha anterior a las pruebas.

**La mejora más clara sin perder calidad visual es compartir texturas
idénticas: unos 214 MiB de datos importados evitables.** La auditoría no
justifica una reducción general de polígonos del mobiliario para solucionar
los FPS del pueblo. Los modelos originales grandes no siempre son los que
más cuestan una vez que Godot aplica sus LOD.

## Condiciones de medida

Apple M2, 8 GB, Godot 4.7, Compatibility/OpenGL sobre Metal, 1280×720,
escala 100%, detalle normal y sombras normales. Cámara del jugador en el
pueblo, frente a la casa 3, con el personaje aproximadamente en `(26,0,36)`.
Se reutilizó el mundo real y la protección contra escritura de partidas del
perfilador existente, con actores pasivos de cliente.

Se hicieron dos tipos de prueba:

- **Mundo activo:** conserva las actualizaciones normales. Sirve para comprobar
  si una reducción del coste gráfico mejora realmente los fotogramas.
- **Escena congelada:** se desactivaron temporalmente las actualizaciones y la
  física del mundo para aislar su presentación. Ocultar una categoría completa
  sirve de límite superior de su coste; no es una optimización utilizable en
  partida ni una promesa de mejora al retocar sus assets.

Cada muestra dura cinco segundos después de estabilizar la vista. Hay
controles intermedios y restauración final. Los valores de `camera_candidate`
del inventario usan frustum y distancia: no representan visibilidad a través
de paredes ni selección exacta del LOD. Los contadores del renderer y las
pruebas de ocultación son los que atribuyen el trabajo dibujado.

## 1. Texturas duplicadas: primera prioridad

Entre los 658 caminos de textura cargados del perfil anterior se encontraron
105 grupos de imágenes con SHA-256 idéntico y 218 copias adicionales.
Comparando además todos los parámetros de importación compatibles, los
datos S3TC redundantes suman **214,0 MiB**. Es una estimación del ahorro de
texturas importadas; hay que verificar la VRAM final después de unificarlas.
No implica un aumento de FPS equivalente a ese porcentaje.

El caso más claro está en `assets/models/props/lake/`:

| Imagen | Copias idénticas | Datos redundantes estimados |
|---|---:|---:|
| Normal de granito, incluido el denominado húmedo | 16 | 40,0 MiB |
| Rugosidad de granito, incluida la denominada húmeda | 16 | 40,0 MiB |
| Color de granito húmedo | 8 | 18,7 MiB |
| Color de granito seco | 8 | 18,7 MiB |
| **Total del lago** | **48 archivos para 4 imágenes** | **117,3 MiB** |

Por ejemplo, `lake_boulder_0_lake_granite_normal.jpg` y las variantes
equivalentes de `lake_slab_*` y `lake_outcrop_*` contienen la misma imagen.
También hay duplicados en acabados de edificios, mobiliario, redes de
camuflaje y recursos de personajes.

**Trabajo propuesto:** hacer que los GLB compartan referencias a las mismas
imágenes, conservando sus materiales, UV, tintes y parámetros propios.
Reimportar y comparar las vistas. El ahorro no requiere bajar la resolución
ni recomprimir las fuentes con más pérdida.

**Riesgo:** referencias de recursos e importación. Conservar las fuentes que
necesiten otros modelos y comprobar la carga de todos los GLB afectados.

## 2. Modelos y LOD: candidatos concretos

| Asset | Triángulos originales | Mallas/superficies | Mínimo sumando sus últimos LOD |
|---|---:|---:|---:|
| `assets/models/props/post_apocalyptic_fridge.glb` | 237.182 | 20, con 2 materiales | 1.004 |
| `assets/models/props/clogged_old_sink_cabinet.glb` | 61.342 | 11, con 11 materiales | 57.534 |
| `assets/models/props/rowboat_animated.glb` | 262.048 | 11 | 18.524 |

Estos mínimos describen los LOD disponibles, no el nivel seleccionado en
cada fotograma. Todos estos modelos ya tienen `meshes/generate_lods=true`.

### Frigorífico

Sus 20 mallas tienen LOD efectivos. En la escena congelada, ocultar los
frigoríficos elimina 218 llamadas de dibujo pero solo 45.402 primitivas
respecto a los 6,83 millones de la vista. El tiempo mediano cambia de
30,04 a 29,89 ms, dentro de la variación de los controles.

En el mundo activo tampoco apareció una mejora de FPS al ocultarlos.
**No priorizar su decimación por el número de polígonos del original.**
Sí se puede estudiar unir las 20 piezas estáticas por sus dos materiales,
preservando dimensiones, UV y colocación. La mejora total sería limitada:
ni siquiera retirar el modelo completo dio una ganancia medible aquí.

### Mueble del fregadero

Siete de sus once superficies no tienen reducciones LOD; el mínimo disponible
conserva aproximadamente el **94 %** de los triángulos. Es un candidato más
razonable para limpiar geometría y reconstruir LOD en el asset.

Al ocultarlo en el mundo activo, las primitivas bajan aproximadamente de
6,82 a 6,42 millones, pero los FPS no mejoran de forma medible en esta vista.
Es una mejora potencial de geometría e interiores, con prioridad inferior a
la deduplicación de texturas. Necesita comparación cercana para conservar
grifos, silueta, huecos, UV y aspecto del material.

### Otros modelos

El barco dispone de LOD efectivos aunque su original sea grande. La cama
tiene 16.720 triángulos; el mueble principal 3.008; el inodoro 848 y el lavabo
484. No hay evidencia para rebajarlos indiscriminadamente.
El GLB `leafy_floor.glb` tiene 936.481 triángulos en su escena original,
pero ese número no aparece como coste de una instancia equivalente en el
inventario de esta vista: el juego construye su terreno de otra forma.

## 3. Dónde se concentra el dibujado del pueblo

La escena congelada presenta 4.496 llamadas de dibujo y unas 6,83 millones
de primitivas:

| Diagnóstico temporal | Llamadas de dibujo | Primitivas | Tiempo mediano |
|---|---:|---:|---:|
| Todo visible | 4.496 | 6.826.257 | 30,04 ms |
| Exteriores de casas ocultos | 2.690 | 6.613.439 | 27,58 ms |
| Interiores ocultos | 4.120 | 6.329.649 | 29,62 ms |
| Hierba oculta | 4.421 | 2.736.937 | 27,36 ms |
| Sombras desactivadas | 2.328 | 6.051.560 | 20,96 ms |
| Escala de render al 50 % | 4.496 | 6.826.257 | 28,62 ms |
| Umbral LOD 8, frente a 2 | 4.496 | 6.581.516 | 27,80 ms |
| Todo restaurado | 4.496 | 6.826.257 | 29,34 ms |

Los exteriores explican unas **1.806 llamadas**, aproximadamente el 40 %.
La hierba explica unos **4,09 millones de triángulos**, aproximadamente el
60 % de las primitivas de esta vista. Hay 838 nodos de exteriores candidatos
en cámara, con 847 superficies y 205 materiales distintos.

Buena parte de las fachadas, marcos, ventanas y puertas se construye en
`Main._create_house_details`, `_create_house_windows` y el sistema de puertas.
La hierba dominante sale de `Main._build_grass_variant_mesh` y sus MultiMeshes.
**Esos costes no se pueden resolver editando únicamente los GLB existentes.**
Agrupar esa geometría o cambiar las matas requeriría modificar su construcción.
Los decals de las casas ya están agrupados; no se propone deshacerlo.

## 4. Comprobación con el mundo activo

| Muestra | FPS medios | Tiempo mediano | Llamadas p95 |
|---|---:|---:|---:|
| Configuración normal inicial | 18,8 | 52,78 ms | 4.498 |
| Preset existente de sombras bajas | 19,0 | 51,45 ms | 3.581 |
| Normal restaurado | 19,1 | 52,12 ms | 4.498 |
| Normal, segundo control | 18,5 | 53,35 ms | 4.501 |
| Muebles del fregadero ocultos | 18,2 | 54,13 ms | 4.421 |
| Frigoríficos ocultos | 17,6 | 54,42 ms | 4.280 |
| Todo restaurado | 18,6 | 53,29 ms | 4.498 |

Retirar esos muebles reduce el trabajo dibujado pero no aporta una mejora
medible del fotograma con las actualizaciones activas. Las pequeñas diferencias
entre muestras no prueban que ocultarlos empeore el rendimiento. Tampoco se
justifica prometer una mejora grande con el preset de sombras bajas en esta
escena, pese a que reduce llamadas.

Hay un coste adicional relevante de actualización, física y envío al renderer
que esta auditoría no atribuye a una función concreta. No se puede extrapolar
el rendimiento de la escena congelada a una partida.
Se descarta la muestra `live_no_sun_shadows` como preset estable: el ciclo
diurno vuelve a establecer `sun.shadow_enabled` durante la prueba.

## 5. Mipmaps: candidato de calidad y ancho de banda

Hay 64 texturas activas de al menos 1024 píxeles sin mipmaps. Las cinco de
4096×4096 que conviene revisar primero son:

- `assets/external/polyhaven/rocky_terrain_02/textures/rocky_terrain_02_diff_4k.jpg`
- `assets/external/polyhaven/rock_07/textures/rock_07_diff_4k.jpg`
- `assets/external/textures/wood_floor_deck/wood_floor_deck_diff_4k.jpg`
- `assets/external/polyhaven/ganges_river_pebbles/textures/ganges_river_pebbles_diff_4k.jpg`
- `assets/external/textures/concrete_floor_02/concrete_floor_02_diff_4k.jpg`

Añadir sus cadenas completas de mipmaps conserva el detalle cercano y puede
mejorar filtrado y acceso a memoria a distancia. Añadiría aproximadamente
13,3 MiB a sus datos S3TC actuales de 40 MiB. **No se ha aplicado ni medido
su beneficio**; debe comprobarse el aspecto lejano y el tiempo de fotograma.

## Evidencia local

- `build/tmp/asset_source_audit.json`: 263 GLB, geometría y duplicados activos.
- `build/tmp/village_asset_audit_inventory.json`: geometrías instanciadas,
  recursos, materiales, rangos y LOD reales importados.
- `build/tmp/village_asset_audit_profile.json`: pruebas con escena congelada.
- `build/tmp/village_asset_live_profile.json`: controles con el mundo activo.
- `build/tmp/village_asset_audit_view.png`: vista utilizada.
- `build/tmp/village_asset_low_shadows.png`: mismo encuadre con sombras bajas.
- `build/tmp/asset_audit_manifest.json`: huella del estado inicial del repositorio.

Las herramientas temporales son `asset_source_audit.py`,
`VillageAssetAudit.gd` y `VillageAssetAuditEntry.gd`, bajo `build/tmp/`.
No se exportó ni publicó ningún cliente durante esta auditoría.

La unificación autorizada posteriormente y sus resultados están documentados
en [TEXTURE_UNIFICATION.md](TEXTURE_UNIFICATION.md).

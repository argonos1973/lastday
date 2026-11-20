# Rendimiento del cliente: agua, pueblo, ciudad y cámaras

Medición del 20-11-2026, Apple M2 con 8 GB, Godot 4.7 Compatibility/OpenGL sobre
Metal, ventana 1280×720, escala 100%, detalle normal, VSync desactivado.
Referencia: código publicado `a464ac7` en un worktree independiente, con el
mismo perfilador actualizado. Resultado: cambios locales de esta revisión.

## Cambios y causas

- El cliente mantenía 3.576 GiB de texturas en GPU. El inventario de recursos
  cargados encontró 328 texturas sin compresión de GPU; las rocas del lago
  aportaban aproximadamente 1 GiB y el kit de interiores 542 MiB.
  Se activó `compress/mode=2` en las 296 texturas activas de al menos 4 MiB:
  se conservan resolución, mipmaps, fuentes, UID y los demás parámetros.
  Godot genera S3TC/BPTC y ETC2/ASTC, como en los materiales ya optimizados.
- La preparación gráfica dibujaba únicamente alrededor del punto de aparición.
  Ahora visita materiales de pueblo, río, lago y ciudad, en ocho direcciones
  y con/sin luz puntual, dentro del viewport real y detrás de la carga.
  También adelanta la primera captura del lago. El jugador permanece inmóvil;
  se restaura su cámara y la visibilidad vuelve a su ubicación al terminar.
  Esto traslada trabajo a la carga inicial.
- La vegetación cercana se centra en el jugador durante vistas normales:
  orbitar la cámara ya no cambia las celdas que hay que construir. Las cámaras
  separadas más de 12 m conservan su propio foco. No se cambian mallas LOD de
  lotes de hierba que están ocultos.
- La búsqueda de interacciones filtraba distancia después de ordenar puertas,
  camas y contenedores de todo el mundo. Ahora solo ordena candidatos que
  están al alcance, conservando desempate, orientación, altura y visibilidad.

## Comparación con recorridos idénticos

Primera aproximación, 16 segundos por zona:

| Zona | p95 antes → después | Máximo antes → después |
|---|---:|---:|
| Pueblo | 187,7 → 67,7 ms | 1.555,3 → 136,1 ms |
| Río | 71,8 → 64,6 ms | 215,1 → 150,3 ms |
| Ciudad | 44,1 → 42,5 ms | 1.619,9 → 170,3 ms |
| Lago | 51,0 → 42,7 ms | 878,5 → 125,3 ms |

Primer ciclo de cambios de cámara, 8 segundos por zona:

| Zona | p95 antes → después | Máximo antes → después |
|---|---:|---:|
| Pueblo | 74,2 → 58,8 ms | 189,7 → 111,1 ms |
| Río | 74,8 → 52,5 ms | 108,5 → 107,4 ms |
| Ciudad | 46,8 → 41,4 ms | 152,6 → 85,1 ms |
| Lago | 51,7 → 46,5 ms | 119,6 → 97,1 ms |

Los 16 escenarios incluyen primera visita y repetición: 192 segundos nominales.
Fotogramas de más de 100 ms: **69 → 21**. De más de 50 ms: **731 → 664**.
Memoria de texturas reportada por el renderer: **3.576 → 1.443 GiB**
(3.661 → 1.477 MiB). Memoria gráfica total: **3.856 → 1.723 GiB**.
Se comprobaron las dimensiones de las 296 texturas cargadas: ninguna cambió.

Los parones grandes de primera visita se reducen, pero quedan picos y una
carga sostenida importante en el pueblo (aproximación: 10,3 → 18,3 FPS medios
en esta máquina). Estos datos no garantizan 60 FPS ni ausencia total de tirones.
Los contadores GPU de tiempo devuelven cero en este backend; no representan
coste GPU nulo. Se usan tiempo real entre fotogramas, tiempos CPU del renderer,
marcas de scripts y memoria. Hay avisos de recursos pendientes al cerrar el
harness; no se observaron errores de scripts durante los recorridos.

## Reproducción y comprobaciones

```sh
LD_CLIENT_PROFILE=1 work/godot4.7/Godot.app/Contents/MacOS/Godot \
  --path . --script tools/debug/CombatFrameProfile.gd -- \
  --traversal --client-visuals --noon --secs=8 --captures --memory-report \
  --out=/Volumes/copia/lastday2/build/tmp/traversal_ground_after.json
```

`--route=village|river|city|lake` limita el diagnóstico a una zona.
`--ab-no-reflections` desactiva las sondas solo en el harness para aislarlas;
no se utilizó en la comparación publicada arriba.
Las alturas de los recorridos exteriores usan el terreno analítico: un rayo
vertical en la posición del actor podría encontrar su propia cápsula.
Los cambios de cámara pasan por la entrada real del controlador. Se descartan
intervalos con la ventana oculta. No se escriben partidas.

Datos locales: `build/tmp/traversal_ground_before.json`,
`build/tmp/traversal_ground_after.json`, sus logs y capturas PNG.
`build/tmp/traversal_memory.json` conserva el inventario inicial de texturas.

Regresiones gráficas verificadas: `WorldEntryRegression`,
`ClientFrameProfilerRegression`, `InteractionRaycastRegression`,
`CityInteriorStreamingRegression`, `NearGroundCoverRegression` y
`WaterFishRegression`, todas sin fallos. Se revisaron capturas del pueblo y
del lago con el renderer real. El chequeo de sintaxis también pasa.

## Cliente macOS exportado

Se exportó `build/macos/LastDay.app`, se instaló `liblastday_nav.dylib` y se
verificó la firma ad-hoc con `codesign --verify --deep --strict`. La regresión
de inventario ejecutada contra el PCK empaquetado termina con cero fallos.

El ejecutable exportado también completó los 16 escenarios mediante
`-- --combat-profile --traversal --client-visuals --noon --secs=8`.
Su log confirma `LastDayNav=true` y aproximadamente 1.440 GiB de texturas.
Registró 11 fotogramas de más de 100 ms y 364 de más de 50 ms.
Máximos de primera aproximación: pueblo 118,2 ms, río 101,3 ms,
ciudad 94,8 ms y lago 128,1 ms. Estos resultados verifican el paquete;
la comparación antes/después de las tablas usa el mismo binario de Godot
en ambos casos. Datos: `build/tmp/traversal_packaged_after.json`.

Esta exportación es local: los cambios todavía no están comprometidos ni
publicados. `version.txt` conserva el HEAD base `a464ac7` conforme al estampado
habitual; no representa un nuevo commit de rendimiento.

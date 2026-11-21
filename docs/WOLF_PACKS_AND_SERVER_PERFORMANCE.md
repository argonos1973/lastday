# Manadas y rendimiento de la IA

La población inicial se mantiene en **23 lobos**, agrupados en siete manadas
de tres o cuatro miembros. Cada grupo empieza con un líder negro.
`WolfPack.gd` es un objeto compartido sin actualización propia ni nodos nuevos.
Los seguidores se reúnen con su guía, aceleran para alcanzarlo y ocupan
posiciones distintas; el guía reduce el paso cuando quedan rezagados.
En pasos estrechos se colocan detrás, conservando la navegación habitual.

Las alertas y los aullidos se comparten dentro de la manada y a distancia
limitada. La caza puede seguir una presa observada por otro miembro; los
flancos alternan por posición en el grupo. Se conservan las comprobaciones
de alcance, protección, paredes, agua y contacto de los ataques.

Cuando muere el líder, los supervivientes permanecen juntos con una guía
provisional. La reposición normal aporta un nuevo líder negro; no cambia
instantáneamente el color de un lobo gris. El reemplazo reutiliza la ruta
del grupo o prolonga su recorrido, evitando nacer en la otra orilla de un
río y manteniendo la separación de las muertes recientes. La reposición
mantiene el límite de 23 animales vivos, contando también los domesticados.
Domesticar un lobo lo separa de su manada y conserva su pelaje.

El material negro reutiliza el modelo y las texturas del lobo. Se conserva
en el cadáver, `Lobo negro muerto`, `Piel de lobo negro`, prendas y tocado,
miniaturas, guardado y restauración. Los paquetes de fauna añaden `pk`,
`alpha` y `black`; los clientes antiguos pueden ignorar esos campos.
Las pieles usan la textura existente con un tinte, sin otra textura grande.

## Trabajo de servidor

1. Se desglosan percepción de amenazas, suministros, botín y forrajeo en los
   contadores existentes. El análisis de funciones encontró comprobaciones
   de iluminación y restricciones ejecutadas sobre alimentos lejanos.
   El forrajeo ahora descarta primero por distancia, conservando prioridades,
   reservas, maduración, seguridad y alcance vertical.
2. La percepción amplia de los bots recibe un turno por fotograma, rotando
   entre los actores que deben actualizarla. Movimiento, necesidades,
   reacciones, combate y planes siguen avanzando para los cuatro cada tick.
3. La fauna conserva el LOD según observadores: humanos cercanos o apuntando,
   bots en su radio de interacción y actualizaciones espaciadas a distancia.
   Los lobos espacian a unos 0,2 s las búsquedas de comida vacías o lejanas y
   conservan una presa viva y cercana durante la persecución. Una muerte
   observada se puede aprovechar inmediatamente. Los alimentos cercanos
   siguen revalidándose para respetar reservas y agotamiento.

## Comparación local

`ServerAIProfile.gd` compila en memoria el código de `HEAD` (`1da44eb` en
esta medición). Genera los candidatos del mapa real y compara ambas versiones
en el mismo proceso. Las **96 elecciones de forrajeo coinciden**, con 2.161
acciones del mundo y casos de día/noche, varias posiciones y radios.

| Operación | Antes | Después |
|---|---:|---:|
| Consulta de forrajeo de día, mediana | 2,044 ms | 0,664 ms |
| Consulta de forrajeo de noche, mediana | 3,709 ms | 0,732 ms |
| Decisión de caza de 23 lobos entre 71 animales, mediana por paso | 2,142 ms | 1,017 ms |
| Pico observado en ese escenario de caza | 2,896 ms | 2,152 ms |

Son tiempos de esas operaciones en la máquina de desarrollo. Los FPS del
servidor `.23` deberán medirse al desplegar. Informe reproducible:
`build/tmp/server-ai-performance.json`.

Las regresiones comprueban pertenencia, seguimiento, alertas, caza,
sucesión, separación al domesticar, guardado, paquetes remotos y pelaje.
Una prueba de cinco segundos mantiene la persecución con una sola búsqueda
de presa y 25 búsquedas de cadáveres. La prueba de 24 lobos distantes registra
un máximo de dos decisiones por fotograma y 48 comprobaciones de posición
en dos segundos. Las consultas de carne ignoran 3.000 acciones ajenas.

Comandos:

```sh
work/godot4.7/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/debug/ServerAIProfile.gd
work/godot4.7/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/debug/WolfPackRegression.gd
work/godot4.7/Godot.app/Contents/MacOS/Godot --path . --script tools/debug/WolfPackRegression.gd -- --capture
work/godot4.7/Godot.app/Contents/MacOS/Godot --path . --script tools/debug/DeadAnimalThumbnailRegression.gd
```

La captura se guarda en `build/tmp/wolf_pack_preview.png`. La prueba gráfica
de miniaturas compara también la luminosidad del cadáver negro con el gris.
`PeltCraftingRegression` verifica fabricación y serialización de guantes y
tocado negros; `PeltClothesPreview` muestra el tocado, la chaqueta y las botas
negros junto al resto de especies.

El cliente macOS local se exportó y su firma ad-hoc se verificó con
`codesign --verify --deep --strict`. Dentro del paquete pasan
`SurvivalInventoryRegression`, `PickupAnimRegression`, `WolfPackRegression`
y `PeltCraftingRegression`. Esta tanda todavía no se ha desplegado.

## Revisión del guardado y los alijos (21 de noviembre de 2026)

La observación del servidor después del despliegue detectó caídas intermitentes
fuera del arranque. En tres minutos sin jugadores, 82 actualizaciones del
monitor dieron una mediana de 56,5 FPS, una media de 49,8 y un mínimo de 8.
Los contadores situaban el mayor coste en la actualización de Carlos.

Una reproducción aislada encontró un bucle concreto: un arco sin flechas se
retiraba del alijo y se devolvía en la misma actualización. Ciento veinte
actualizaciones generaban 120 solicitudes de guardado sin ningún cambio neto.
La elegibilidad del arma ahora comprueba estado y munición; el caso genera
cero solicitudes. La inspección de un fusil nuevo no concede su munición
inicial. Los umbrales preventivos para buscar comida y agua se usan también
al retirarlas, evitando viajes al alijo que no resolvían la necesidad.

Los cambios del mundo se agrupan con una cadencia de dos segundos y un único
escritor. El hilo principal comprueba si terminó el trabajo anterior; no espera
si sigue activo. La información de jugadores se conserva inmediatamente para
las reconexiones, aunque desaparezca un proxy antes del siguiente snapshot.
El cierre explícito drena también el último estado pendiente.

`ServerSaveRegression` simula una escritura ocupada durante 250 ms: tramitar
100 solicitudes tarda aproximadamente 3,4 ms en la máquina de desarrollo y
se verifica que termina guardándose el estado más reciente. También pasan
las pruebas de reinicio, munición, fabricación de pieles, planes y combate.

La telemetría añade supervivencia, necesidades, movimiento, búsqueda de agua,
alijos y posiciones junto al fuego. Estos tiempos están incluidos en los de
cada actor. El divisor de ms/s usa tiempo real monotónico: el delta del motor
se limita durante los atascos y podía producir cifras superiores a 1000 ms/s.
`frame_p95` y `frame_max` miden los intervalos reales entre actualizaciones del
servidor, incluyendo las esperas. La comparación tras desplegar debe observar
varios minutos de actividad y anotar cuántos jugadores hay conectados.

La primera medición con estos contadores detectó otro coste: aproximadamente
450 ms/s en búsquedas de agua. La prevención de sed consultaba todos los
candidatos cada fotograma. Ahora reutiliza el resultado durante un máximo de
500 ms y mientras el bot no se haya alejado más de 2 m. Un nuevo veto, perder
la iluminación o el permiso para ir al destino, cambiar de noche/día o entrar
en sed crítica fuerza una nueva consulta. Beber y las búsquedas urgentes
conservan sus comprobaciones. La regresión de percepción comprueba que 120
consultas consecutivas en el mismo lugar realizan una sola búsqueda completa,
y que movimiento, veto, urgencia, iluminación y caducidad la invalidan.

## Grabaciones de lobos aportadas en `LOBOS`

| Original | Uso |
|---|---|
| `LOBO_ANDANDO.mp3` | Tres contactos de patas al caminar. |
| `LOBO_CORRIENDO.mp3` | Tres contactos de carrera, con cadencia de galope. |
| `LOBO_COMIENDO.mp3` | Tres fragmentos de masticación mientras se reproduce la acción de comer. |
| `LOBO_GRUÑENDO.mp3` | Cuatro gruñidos para amenazas, persecuciones y combate entre lobos. |

Los originales se conservan intactos. Los 13 recortes son WAV mono a 24 kHz,
con fundidos y picos de −6 dBFS; los tiempos y hashes están en
`assets/audio/wildlife/SOURCES.json`. Regeneración:
`python3 tools/audio/build_wildlife_audio.py --wolves-only`.
El archivo de gruñidos puede tener la eñe descompuesta en macOS; el importador
resuelve ambas formas Unicode.

Los pasos mantienen la lógica de desplazamiento real, sin sonido al quedarse
quietos o teletransportarse. La masticación usa la pose `eat` ya sincronizada,
reutiliza la voz espacial del lobo y se cancela al cambiar de acción, atacar,
morir o alejarse del oyente. No añade RPC ni reproductores al servidor dedicado.
Los aullidos, quejidos de hambre, heridas, ataques y mordiscos conservan sus
grabaciones específicas. `WildlifeAudioRegression` comprueba las asignaciones,
la interrupción de comidas, la cadencia a distintas tasas de fotogramas y,
con `--require-output` sin `--headless`, la salida del mezclador real.

Validación de esta integración: 152 comprobaciones headless y 161 con CoreAudio,
sin fallos de aserción; pasan también manadas, domesticación y caza. El cliente
macOS se regeneró y se verificó su firma ad-hoc. Dentro del paquete pasan
`WildlifeAudioRegression` y `SurvivalInventoryRegression`. La comprobación de
CoreAudio usó un proyecto temporal sin entrada de micrófono; el proyecto y
las preferencias de audio del usuario no se modificaron.

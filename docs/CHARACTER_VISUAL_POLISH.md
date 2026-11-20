# Personajes: materiales y presentación

Esta revisión conserva la geometría del personaje, sus prendas y sus
animaciones de equipo. Corrige materiales que ocultaban detalle disponible
en las texturas y mejora su lectura con la misma iluminación.

- Piel: se activa el normal existente, se eliminan las asignaciones de metal
  y brillo procedentes de la importación FBX y se ajusta la respuesta de la
  superficie. Los personajes guardados conservan las texturas originales
  al aplicar su color en el menú.
- Ojos y pestañas: los ojos mantienen su atlas con un material específico.
  La antigua textura de pestañas tenía alfa opaco; se deriva una máscara
  de 512 px del alfa original de Remy. Desaparece el borde negro sólido
  alrededor de los ojos.
- Pelo: reflejos más suaves, sin respuesta metálica.
- Ropa y calzado: relieve y reflejos diferenciados para tejido y cuero.
  Los normales de camiseta, pantalones y zapatillas generan mipmaps.
  El normal de botas militares usa compresión de normales y mipmaps,
  importado a 1024 px; el albedo y la geometría conservan su resolución.
  El tinte de las botas permite distinguir cuero, cordones y suela.

La máscara de pestañas se regenera con
`python3 tools/generate_character_detail.py`.
Se conserva compresión para GPU en los recursos modificados.

## Comparación aislada

Escena de revisión con tres personajes, mismos atuendos, cámara e iluminación,
Godot 4.7 Compatibility sobre Apple M2. Las capturas y los informes se guardan
en `build/tmp/character_appearance/{before,after_v2}/`.

| Medida | Antes | Después |
|---|---:|---:|
| Llamadas de dibujo | 28 | 28 |
| Primitivas | 128 427 | 128 427 |
| Texturas | 247,11 MiB | 246,11 MiB |
| Memoria gráfica | 273,69 MiB | 272,69 MiB |
| Memoria estática | 73,96 MiB | 74,07 MiB |
| Tiempo medio | 10,00 ms | 6,56 ms |
| P95 | 19,76 ms | 8,22 ms |

Son mediciones de esta escena, con variación de carga entre ejecuciones:
no representan una mejora de FPS del mundo completo. La comprobación útil
es que no aumentan geometría, llamadas de dibujo ni memoria gráfica.

La corrección de bebida/comida está descrita por separado en
`MIXAMO_ANIMATION_SELECTION.md`: sonido asociado al contacto con la boca
y una captura específica de comer, de aproximadamente 96 KiB.

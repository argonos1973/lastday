# Ciudad: revisión y siguiente ampliación

Revisión del 12 de octubre de 2026, checkout `/Volumes/copia/lastday2`, rama `multiplayer`, referencia `6595d78`. Este documento propone trabajo futuro; no añade edificios ni modifica el mapa.

## Avance de implementación

- **Anillo vial — geometría añadida, pendiente de comprobar dentro del juego.** `CityRoad.gd` genera cuatro tramos que cierran los extremos de la retícula; `CityExpansion.on_road` reconoce esa misma huella para el resto de sistemas. Está dentro de la reserva actual y no cruza los cauces definidos en el mapa. El trazado aún necesita una revisión visual y de navegación en Godot.
- El bloque alto jugable sigue siendo el siguiente paso. No se ha añadido ningún edificio decorativo.

## Estado comprobado

- `CityBlock.BUILDINGS`: 16 viviendas, cuatro modelos repetidos por `i % 4`, todas con dos plantas. Plantas a 0,12 y 3,92 m; huella de 12 × 12 m. Cambiar colores no resolverá la repetición de siluetas, distribución y usos.
- Dos calles longitudinales en x=9 y x=73; transversales en z=680 y z=776. Calzada de 7 m. La primera enlaza con el final real de la carretera existente. Los extremos del barrio siguen abiertos.
- Hay aceras, arbolado, coches, mobiliario, fuente y torre del reloj al sur de la plaza, en (41,0,750). No hace falta otra torre como hito: conviene que los edificios nuevos queden por debajo de ella.
- Casas con cubierta plana: escalera interior de retorno hasta la azotea. Casas con cubierta inclinada: techo cerrado, sin acceso al tejado. La torre tiene siete tramos con descansillos, hasta 29,4 m.
- El cruce de río del acceso es un vado; el puente antiguo ya no existe. La carretera omite caras bajo el agua.
- Reserva actual sin bosque: x entre -46 y 130, z entre 440 y 840; terreno hacia el sur hasta z=900. Ampliar fuera de esta reserva exige actualizar vegetación y límites asociados.
- El reloj lee la hora local del ciclo día/noche. No se ha comprobado coincidencia entre máquinas con relojes distintos.

La captura aérea guardada `outputs/level1_city_aerial.png` permite revisar la retícula inicial, pero es anterior a la torre y a la fuente actuales. No se considera una captura de todo el estado de hoy.

## Orden de trabajo propuesto

### 1. Cerrar las calles y definir parcelas

Primero completar una ronda que una los extremos existentes. Trazado candidato, en coordenadas del mundo:

- Oeste x=-31 y este x=113, desde z=640 hasta z=816.
- Norte z=640 y sur z=816, desde x=-31 hasta x=113.
- Mantener el acceso norte por x=9 y las cuatro intersecciones actuales.
- Conectar aceras mediante rebajes, dejar pasos peatonales y entradas de servicio. La plaza y la torre deben conservar accesos libres.

Es una propuesta geométrica, no un trazado aprobado por pruebas de terreno. Antes de generar: muestrear cauces y altura, comprobar las huellas de casas, árboles, vehículos y mobiliario. Si cruza agua, resolver el paso expresamente como puente o vado; no extender asfalto sobre la superficie del río.

Extraer una definición común de segmentos para malla, colisión, `on_road`, aceras y exclusión de vegetación. Hoy `CityRoad` y `CityExpansion.on_road` duplican el trazado: ampliar solo una parte produciría discrepancias. Revisar también que la colisión necesaria esté disponible en servidor; `CityRoad` se crea actualmente en la rama cliente.

### 2. Un edificio piloto de cuatro plantas, completamente jugable

Crear en Blender un bloque residencial envejecido, con planta baja comercial, tres plantas superiores y escalera interior en U. No estirar una casa existente ni colocar una carcasa vacía: modelar cada planta, descansillo, hueco y puerta como espacio real por el que el personaje pueda moverse.

- Fachada de ladrillo/revoco, balcones deteriorados, bajantes, ventanas de distintos estados y cubierta parcialmente dañada.
- Entrada legible, pasillos despejados, locales en planta baja y viviendas con distribuciones distintas arriba.
- Todas las plantas accesibles desde el suelo por puertas de altura jugable y una escalera continua; permitir subir, bajar y permanecer en cada piso sin atravesar techos ni quedarse atascado.
- Colisiones de suelo, paredes, escaleras, barandillas y muebles ajustadas al controlador. Huecos de puertas y ventanas practicables cuando el diseño indique acceso; evitar mallas cerradas que parezcan huecas pero bloqueen al personaje.
- Contenido funcional: loot colocado en interiores y accesible, puertas que abren/cierran y persisten/sincronizan en multiplayer, camas utilizables y contenedores u otros muebles solo si tienen una interacción real. Los props sin interacción pueden decorar el interior, pero ningún edificio será solo decorativo ni fachada inaccesible.
- Mantener colisiones y lógica de interacción en servidor; ocultar allí solo la parte visual. Probar entrar, abrir, saquear, subir, bajar y salir con cliente y servidor.
- Mantener el criterio de 3,9 m entre plantas durante el piloto para reutilizar medidas verificadas. Comprobar proporciones visuales antes de fijarlo para todo el barrio.
- Probar entrada, subida, giro, parada en cada planta y bajada con el controlador real, además de las cápsulas de regresión.

El código no admite alturas diferentes solo añadiendo un GLB: sustituir el módulo `i % 4` por una definición por edificio con `model`, `floors`, `bounds`, `interior_layout` y puertas. Adaptar `inside_building` (actualmente y<7,9 y huella fija), loot, muebles, refugio e IA a esos datos. Mantener los IDs y orden de los edificios existentes; añadir nuevos al final.

### 3. Diversidad: cuatro edificios nuevos antes de crecer más

Primer lote propuesto, total de 20 edificios residenciales/comerciales/industriales más la torre:

| Cantidad | Tipo | Función y aspecto |
|---|---|---|
| 1 | Bloque de cuatro plantas con comercio | Tienda con mostrador/loot y acceso real a las tres plantas habitables |
| 1 | Edificio de tres plantas en esquina | Tienda, farmacia o clínica saqueable abajo; viviendas accesibles arriba |
| 1 | Taller o almacén de una planta alta | Portón practicable, espacio transitable y loot industrial recogible |
| 1 | Edificio de dos o tres plantas parcialmente derruido | Daños con colisiones coherentes, ruta interior transitable y habitaciones accesibles; escombros solo donde no bloqueen el paso previsto |

Situar las parcelas después de verificar el anillo y los cauces; no ocupar el corredor de la plaza con una fachada alta. Alternar alturas de 1–4 plantas, retranqueos y materiales. Si una parcela no cabe, ampliar una franja concreta con su reserva de terreno, en lugar de dispersar casas por el bosque.

### 4. Dar continuidad y deterioro creíble

Crear pequeños patios, muros bajos, accesos traseros, marquesinas y aparcamientos. Vincular los daños a la construcción: escombros bajo una fachada colapsada, filtraciones bajo cornisas, vegetación en juntas. Evitar repetir manchas grandes y montones idénticos en cada casa. Unificar materiales nuevos con los de la ciudad, conservando contraste entre residencial y zona industrial.

## Modelos encontrados

Fichas de autores/tiendas consultadas el 12/10/2026. No se han descargado, comprado ni probado los archivos. Ningún candidato se considera listo para integrarse como edificio jugable hasta verificar interiores, colisiones, escala, accesos y licencia. Las fachadas o shells cerrados no cumplen el requisito.

| Candidato y fuente | Formato/licencia anunciados | Uso recomendado y límite |
|---|---|---|
| [Abandoned City Buildings Asset Pack — Kawaljeet Singh Batra](https://www.artstation.com/marketplace/p/bbxzb/abandoned-city-buildings-asset-pack) | 10 edificios; `.blend`, `.glb`, FBX y OBJ. De pago: licencia estándar limitada o comercial ampliada. | Mejor referencia visual a evaluar. La ficha no confirma interiores recorribles, así que no insertar el modelo tal cual: exigir archivos fuente modificables y construir/verificar plantas, accesos y colisiones en Blender. |
| [Downtown City MegaKit — Quaternius](https://quaternius.com/packs/downtowncitymegakit.html) | CC0; parte gratuita en glTF/FBX/OBJ, versión Source con `.blend` y proyecto Godot. | Piezas modulares útiles para construir estructuras que sí se puedan recorrer. Su estilo Boston/NYC necesita adaptación. El interior simulado de ventanas no cuenta como interior jugable. |
| [Industrial Modular Game-Ready Asset Pack — 4X Assets](https://superhivemarket.com/products/industrial-modular-asset-pack) | 109 piezas; Blender 4.3, licencia anunciada Royalty Free, de pago. La ficha leída no detalla extensiones incluidas. | Potencial kit para construir un almacén jugable con paredes, escaleras y plataformas. Confirmar exportación e interacciones/colisiones al probar una muestra; no es un edificio completo listo. |
| [Abandoned Building Modular — Barryfillx](https://sketchfab.com/3d-models/abandoned-building-modular-38bd011a10fb4447b00218b6fa557882) | Ficha indexada: descarga gratuita, CC Attribution, 14,7 mil triángulos. Formato original sin verificar. | La ficha no permite confirmar interior ni colisiones y la página directa no cargó. No usarlo como edificio de la ciudad sin rehacer y probar toda la parte jugable. |
| [City Kit Commercial — Kenney](https://kenney.nl/assets/city-kit-commercial) | 50 piezas, CC0; formatos no detallados en la página consultada. | Útil para probar volúmenes y calles. No sería mi elección para el acabado realista y devastado pedido. |

El pack de ArtStation anuncia estándar con límite de 2.000 ventas o 20.000 visualizaciones; la opción comercial ampliada anuncia proyectos y ventas sin esos límites. Revisar el texto vigente al adquirirlo. No se ha adquirido ninguna licencia.

El [Abandoned Office Block](https://www.fab.com/listings/aef5aeb3-d6eb-4a77-a74c-ed1067507e4c) ofrece FBX/GLB, pero el autor recomienda verlo a distancia; queda descartado como edificio jugable. La licencia concreta tampoco quedó expuesta en la ficha consultada. Ningún edificio de la lista debe aparecer en el mapa solo para llenar el horizonte.

## Rendimiento y validación

Las mediciones guardadas son anteriores a la torre y últimos ajustes, no un benchmark actualizado: Apple M2, 1280×720, aproximadamente 61 FPS en calle, 48 en interior y 34 en vista aérea, con unos 1.052 MB de VRAM. El diagnóstico sin sombras subía a unos 94 FPS en calle y 46 en aérea: revisar sombras y visibilidad tiene valor antes de multiplicar edificios; no implica desactivar todas las sombras.

Antes y después de cada lote: repetir `CityPerfSnapshot` con mismas vistas/configuración, sumar una vista desde la torre y otra del edificio piloto, registrar tiempos de cuadro p50/p95, llamadas de dibujo y memoria. El ensayo gráfico aislado no representa IA, tormentas ni multiplayer en juego completo.

- Exterior simplificado a distancia; interiores y objetos pequeños ocultos por distancia/planta cuando sea seguro. Actualmente los muebles tienen alcance de 48 m; los edificios del mundo permanecen residentes.
- Compartir materiales/texturas y agrupar objetos repetidos. Colisiones simples separadas del detalle visual; no usar cada cascote como cuerpo físico.
- Mantener colisiones, puertas y datos de loot disponibles en el servidor aunque no dibuje. Probar un cliente tardío, puertas y loot de plantas superiores.
- Pruebas repetidas hoy: parse de `Main.gd` sin errores; `CityBlockRegression` y `ClockTowerRegression`, ambas con cero fallos. Son pruebas aisladas; no certifican partida multiplayer ni todos los recorridos con cámara y animación.

Siguiente entrega recomendada: anillo vial verificado y un bloque de cuatro plantas completo con recorrido, loot, puertas y colisiones probados. Aceptar el modelo solo tras poder entrar desde la calle, interactuar con sus elementos y recorrer todas las plantas tanto en cliente como en servidor; luego medir el coste antes de producir los otros tres edificios.

# Un dia mas

Prototipo jugable en Godot 4.x de supervivencia single player sin zombies.

## Como abrirlo

Opcion directa:

1. Haz doble clic en `outputs/Abrir_Un_Dia_Mas.command`.
2. Haz clic dentro de la ventana del juego para capturar el raton.

Opcion desde Godot:

1. Abre Godot 4.x.
2. Importa esta carpeta como proyecto.
3. Ejecuta la escena principal `res://scenes/Main.tscn`.

## Controles

- WASD o flechas de direccion: moverse
- Raton: mirar
- Clic en la ventana: capturar el raton si no responde
- Shift: correr
- Ctrl: agacharse
- E: interactuar
- F: linterna
- I o Tab: mostrar u ocultar inventario
- R: cambiar el objeto visible en la mano
- 1-4: usar los primeros objetos del inventario
- Escape: liberar o capturar el raton
- Q: salir del juego

## Lo que incluye esta primera entrega

- Movimiento 3D con camara controlada por raton.
- Estadisticas de supervivencia: salud, hambre, sed, energia y temperatura.
- Inventario por slots con peso, objetos iniciales y uso de comida, agua y vendas.
- Loot escaso en armarios, cajas, mochilas, coches y edificios.
- Mapa de prueba con refugio, cinco casas con tejados, puertas, interiores detallados, carretera, bosque mas denso, gasolinera, comisaria, punto de radio, coches abandonados, vallas, postes, barricadas, chatarra, arbustos, hierba, grietas, nubes y cielo procedural.
- Ciclo de dia y noche de 10 minutos reales.
- Frio aumentado durante la noche.
- Linterna que consume pilas.
- Refugio con cama, guardado, baul y radio.
- Radio con mensajes nocturnos aleatorios.
- NPC humano hostil que patrulla, advierte, persigue y ataca.
- Guardado de posicion, estadisticas, inventario, hora, baul y contenedores ya saqueados.
- Sonidos incluidos: pasos en hierba, grava/carretera y madera, ambiente de dia, ambiente de noche y viento.
- Soporte para reemplazar arboles, coches, casas, gasolinera, comisaria, refugio, punto de radio, brazo y sonidos con assets externos.
- Assets Quaternius integrados desde los zips de la raiz: vehiculos, humano hostil, cuchillo, contenedores, barreras, farolas, sofa, baul, barriles, palets, bolsas de basura, tuberias, bloques, senales y torre de agua.
- Assets Kenney integrados desde los zips de la raiz: hierba, hierba alta, parches de hierba, rocas, tienda, cama enrollada, cajas, baules, piezas de suelo, puerta, tejado, metal oxidado, tablones y hoguera.
- Assets de `trees.zip` integrados como arboles naturales por textura con transparencia.
- Assets Quaternius Stylized Nature MegaKit integrados: arboles comunes, arboles retorcidos, algunos arboles muertos, hierba alta/corta, helechos, arbustos, plantas y rocas con texturas.
- Paisaje ampliado: montanas alrededor del mapa, campos de hierba alta, mas bosque, rocas grandes y laderas visuales para cerrar el horizonte.

## Notas de diseno

La escena usa geometria procedural generada por scripts para mantener el prototipo ligero. Ya no depende solo de cubos: usa terreno plano, cielo procedural, cilindros, esferas, conos y tejados triangulares. Para acercarse de verdad a un aspecto DayZ, la siguiente mejora natural es incorporar un asset pack de edificios, vegetacion, armas y vehiculos, anadir sonidos ambientales y ampliar la IA humana con armas, cobertura y rutas de patrulla mas largas.

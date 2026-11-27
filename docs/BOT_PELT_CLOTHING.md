# Fabricación autónoma de ropa de piel

Los cuatro supervivientes usan las mismas recetas que el jugador. Fabrican
cuando sus necesidades y amenazas permiten trabajar y el resultado mejora su
equipo. Necesitan un cuchillo funcional o una alternativa admitida por la receta,
como una piedra afilada. Cada fabricación desgasta la herramienta en 3 puntos.

El destripado usa el nombre y la cantidad de pieles del propio animal, igual
que el jugador: lobo y zorro dan una piel, ciervo dos y oso cuatro. Un oso
proporciona así las cuatro pieles necesarias para fabricar la primera chaqueta.

| Prenda | Materiales consumidos |
|---|---|
| Chaqueta de piel | 4 pieles |
| Pantalones de piel | 3 pieles |
| Botas de piel | 2 pieles |
| Guantes de piel | 1 piel |
| Gorro de piel | 2 pieles y 1 trapo |
| Tocado de piel animal | 3 pieles |

Lobo, lobo negro, ciervo, zorro y oso tienen tocado propio. Las pieles de ave
sirven para ropa; la receta de tocado con aves produce un gorro, como para el
jugador. El bot considera ese resultado real al elegir la receta, evitando
fabricar otro gorro cuando ya lo lleva. Para un tocado prioriza las pieles con
cabeza disponible antes que las de ave. En mezclas, la especie dominante de las
pieles realmente consumidas determina la prenda.

La recogida de pieles considera las prendas que faltan y su coste real. Un
conjunto de cinco piezas con tocado cuesta 13 pieles; el gorro y el tocado ocupan
la misma posición. El tocado supera la prioridad del casco militar. El bot
reserva primero las pieles para mejorar chaqueta, pantalones y cabeza, en ese
orden; después completa botas y guantes. Una prenda que ya iguala o supera la
mejora prevista cubre ese hueco sin gastar pieles. Así, recibirlas una a una de
las cacerías permite reunir las tres o cuatro necesarias para prendas grandes.
Con aves, la reserva de cabeza considera el gorro que realmente saldrá.
Los guantes siguen costando una sola piel.

Los materiales se comprueban otra vez al terminar el trabajo. Si durante una
interrupción desaparece un ingrediente o deja de servir la herramienta, no se
consumen recursos ni se crea una prenda. Una mejora que puede ponerse
directamente no necesita un hueco temporal libre en la mochila. La prenda
sustituida vuelve al inventario o cae al suelo si no cabe.

El servidor conserva el objeto vestido completo en
`saved_extra.worn_clothing`, incluyendo especie y durabilidad. Los nombres
internos de la IA siguen sin sufijos; el guardado y la sincronización visual
usan el formato existente `nombre|especie`. La piel negra y los demás tipos se
mantienen al equipar, reemplazar, soltar, recoger y generar el botín de muerte.
Una prenda vestida y un repuesto del mismo nombre se conservan por separado.
Esto respeta el ciclo de vida existente del mundo: el servidor dedicado genera
una sesión nueva al reiniciarse.

No hay nuevas consultas al modelo de IA, procesos por fotograma ni búsquedas
del mapa. La lista de recetas de piel se prepara una vez; la valoración usa el
equipo y el inventario del bot dentro de las decisiones existentes.

## Verificación

`tools/debug/PeltCraftingRegression.gd` comprueba la fabricación autónoma en los
cuatro NPC, seis tipos de piel, todas las prendas, consumo real, herramienta
rota y alternativa primitiva, interrupción, mezclas, mochila llena, cambio de
ropa, datos serializados, aplicación del equipo remoto y botín de muerte.
Las regresiones de bots/combate, inventario y mochilas cubren las rutas
compartidas. `RightClickDeathRegression` espera la recogida de 1,4 segundos antes
de comprobar el inventario y el desbloqueo de la siguiente interacción.

# Un dia mas - arquitectura de supervivencia

Este documento marca la arquitectura nueva para convertir el prototipo en un survival lento, tenso y realista, sin zombis.

## Carpetas

- `scripts/player/`: jugador, estadisticas, camara e interaccion.
- `scripts/inventory/`: inventario, peso, equipo y almacenamiento.
- `scripts/items/`: recursos de item y objetos recogibles.
- `scripts/world/`: loot, clima, hogueras, agua y sistemas del mapa.
- `scripts/npc/`: humanos, patrulla, vision, ruido y combate.
- `scripts/ui/`: HUD e inventario visual.
- `scripts/save/`: guardado y carga.
- `resources/items/`: items en formato recurso.
- `scenes/items/`: escenas de objetos recogibles.
- `scenes/npc/`: escenas de NPC humano.
- `scenes/ui/`: escenas de interfaz.

## Modulo 1: jugador funcional

Scripts creados:

- `scripts/player/SurvivalPlayerController.gd`
- `scripts/player/PlayerStats.gd`
- `scripts/player/PlayerInteractor.gd`
- `scripts/inventory/InventorySystem.gd`
- `scripts/items/ItemResource.gd`
- `scripts/items/PickableItem.gd`
- `scripts/world/LootSpawner.gd`

### Escena necesaria

Para probar el controlador nuevo en una escena limpia:

1. Crea un `CharacterBody3D`.
2. Asigna `scripts/player/SurvivalPlayerController.gd`.
3. Anade un `CollisionShape3D` con `CapsuleShape3D`.
4. Anade un `MeshInstance3D` si quieres ver un cuerpo provisional.
5. El script crea automaticamente:
   - `PlayerStats`
   - `InventorySystem`
   - `CameraPivot`
   - `Camera3D`
   - `PlayerInteractor`

### Controles

- WASD o flechas: moverse.
- Shift: correr.
- Ctrl: agacharse.
- Espacio: saltar.
- Raton: mirar.
- E: interactuar.
- I: inventario, de momento emite aviso.

### Como conectarlo al mundo actual

El mapa existente todavia usa `scripts/PlayerController.gd` porque tiene animaciones, modelo, manos, mochila y sistemas visuales ya hechos. Los scripts nuevos son la base modular para migrar sin romper el prototipo.

La migracion recomendada es:

1. Sustituir gradualmente `SurvivalStats.gd` por `scripts/player/PlayerStats.gd`.
2. Sustituir `Inventory.gd` por `scripts/inventory/InventorySystem.gd`.
3. Cambiar objetos sueltos a `scripts/items/PickableItem.gd`.
4. Conectar el HUD actual a las senales `changed`, `message`, `item_used` e `item_equipped`.

### Como probar objetos recogibles

1. Crea un `StaticBody3D`.
2. Asigna `scripts/items/PickableItem.gd`.
3. Anade un `CollisionShape3D`.
4. Crea un `ItemResource` y asignalo al campo `item`.
5. Mira el objeto con la camara y pulsa E.

### Errores comunes

- Si no aparece texto de interaccion, revisa que el objeto tenga colision.
- Si no se recoge, revisa que el jugador tenga `InventorySystem`.
- Si no se mueve la camara, pulsa dentro de la ventana para capturar el raton.
- Si no salta, revisa que exista la accion `jump` en `project.godot`.

## Siguiente modulo

El siguiente paso debe ser migrar el jugador actual a `PlayerStats` sin perder:

- modelo en tercera persona,
- animaciones `idle.glb`, `walking.glb`, `correr.glb`,
- objeto visible en mano,
- mochila visible en espalda,
- sonidos de pasos.

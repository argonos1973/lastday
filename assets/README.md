# Assets recomendados para "Un dia mas"

Este prototipo ahora usa geometria y materiales procedurales para poder ejecutarse sin descargas externas.

Para acercarlo mas al aspecto DayZ, descarga modelos y texturas y arrastra sus carpetas a `assets/external/` desde el editor de Godot.

- Kenney Nature Kit: https://kenney.nl/assets/nature-kit
- Kenney Survival Kit: https://kenney.nl/assets/survival-kit
- Kenney Car Kit: https://kenney.nl/assets/car-kit
- Kenney Furniture Kit: https://kenney.nl/assets/furniture-kit
- Quaternius Zombie Apocalypse Kit: https://quaternius.com/packs/zombieapocalypsekit.html
- Quaternius Ultimate Nature Pack: https://quaternius.com/
- Poly Haven: https://polyhaven.com/
- ambientCG: https://ambientcg.com/
- Terrain3D para Godot 4: https://github.com/TokisanGames/Terrain3D
- Sonniss GameAudioGDC: https://sonniss.com/gameaudiogdc/
- Freesound: https://freesound.org/
- Pixabay Sound Effects: https://pixabay.com/sound-effects/

Prioriza archivos `.glb` o `.gltf`. Godot 4 los importa mejor que FBX.

El prototipo detecta automaticamente estos modelos si los colocas en `assets/external/realistic/`:

```text
tree_oak.glb
tree_pine.glb
tree_birch.glb
abandoned_car.glb
rusty_car.glb
wrecked_car.glb
abandoned_van.glb
first_person_arm.glb
```

Para hierba realista:

- Usa texturas PBR de ambientCG o Poly Haven para el suelo.
- Para hierba alta/baja de verdad, conviene convertir matas de hierba a `.glb` y luego dispersarlas con Terrain3D o un sistema de MultiMesh.

Para nubes realistas:

- Usa un HDRI de cielo de Poly Haven para iluminar y dar fondo real.
- Si quieres nubes volumetricas, hace falta un shader/plugin o un skybox HDRI; el prototipo usa capas de nubes transparentes como base ligera.

Estructura sugerida:

```text
assets/external/kenney/nature-kit/
assets/external/kenney/survival-kit/
assets/external/quaternius/zombie-apocalypse-kit/
assets/external/realistic/
assets/external/audio/
```

Licencias:

- Kenney muestra licencia Creative Commons CC0 en sus packs.
- Quaternius indica CC0 en sus packs.
- Poly Haven publica sus assets como CC0.
- ambientCG publica sus assets como CC0.
- Sonniss GameAudioGDC es royalty-free para juegos y produccion audiovisual, pero no CC0.
- Freesound mezcla CC0, CC BY y otras licencias: filtra por CC0 o CC BY.
- Pixabay usa licencia propia; revisa cada sonido antes de distribuir.

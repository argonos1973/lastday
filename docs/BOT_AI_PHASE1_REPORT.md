# Last Day — informe de IA, fase 1

Trabajo local sobre `multiplayer`, con base `f1e1748`. No se ha exportado ni
desplegado esta fase, ni actualizado la web pública. Los archivos del servidor
y de los monitores ES/EN están preparados para una publicación posterior.
Los cambios permanecen en el árbol de trabajo, sin commit ni push de esta fase.
La planificación, la telemetría y el monitor se han validado localmente.
Los fallos de supervivencia diurna detectados durante el trabajo se
reprodujeron y corrigieron; la publicación pública continúa pendiente.

## Archivos y arquitectura

Nuevos:

- `scripts/bot_ai/BotPlanManager.gd`: aceptación, continuidad, pasos, estados,
  relojes, suspensión, reanudación, cancelación, bloqueo y recuperación local.
- `scripts/bot_ai/BotGoalValidator.gd`: propósito, requisitos, resultados
  observados, equipo utilizable, aliados vivos y evidencias de adquisición.
- `scripts/bot_ai/BotInterruptionManager.gd`: motivos y prioridades obtenidos
  del sistema reactivo existente y requisitos de los trayectos cortos de
  recuperación térmica, sin ejecutar otro sistema de combate o navegación.
- `scripts/bot_ai/BotPlanDiagnostics.gd`: historial, contadores y proyección
  segura para `status.json`.
- `scripts/bot_ai/README.md`: interfaces, persistencia, funcionamiento y publicación.
- `tools/debug/BotPlanContinuityRegression.gd` y
  `BotPlanPerformanceRegression.gd`.
- `tools/debug/BotPlanMonitorRegression.cjs` y `BotPlanMonitorBrowser.cjs`.
- `tools/web/bot_plans.js`: presentación compartida de planificación ES/EN.
- Este informe y los seis archivos `.gd.uid` de los nuevos scripts Godot.

Modificados:

- `scripts/SurvivorBotManager.gd`, `scripts/GameConst.gd` y `AGENTS.md`.
  `GameConst` centraliza el radio de refugio de emergencia y los umbrales
  compartidos de alerta/recuperación por calor.
- `tools/debug/BotPlanReliabilityRegression.gd`,
  `BotGoalConsistencyRegression.gd`, `BotDaySurvivalSimRegression.gd`,
  `BotNightSurvivalSimRegression.gd`, `SurvivorBotsAndCombatRegression.gd`
  y `BotMonitorPollingRegression.cjs`.
- `tools/web/bot_monitor.html` y `bot_monitor_en.html`.

El gestor principal pasa de **19.117 a 18.933 líneas: 184 menos**. Los cuatro
módulos suman 793 líneas: planificación 410, validación 254, interrupciones 69
y diagnósticos 60. La reducción es incremental: la ejecución reactiva,
el mundo, la navegación y la autoridad del servidor siguen en el coordinador.

Se extrajeron las implementaciones de `_ai_apply_decision`, `_ai_advance_plan`,
`_ai_step_stalled`, `_ai_fail_stalled_step` y `_ai_directive_completed`,
conservando sus interfaces como delegaciones. También se separaron la
comprobación de armas útiles, la selección del aliado vivo y la validación de
evidencias de adquisición. Los módulos no precargan el coordinador: reciben sus
consultas existentes. No hay dependencia circular ni otro planificador.

## Continuidad, descanso y emergencias

`ai_directive` sigue siendo el único plan activo. Conserva identidad, objetivo
estratégico, paso, destino, prioridad, origen, pasos restantes, evidencias y tiempos.
Los estados son `RUNNING`, `SUSPENDED`, `COMPLETED`, `FAILED` y `CANCELLED`.
Los resultados terminales permanecen aunque empiece otro plan.

Dormir suspende una misión incompatible. Combate, huida, sed, hambre,
temperatura, heridas, agotamiento, refugio nocturno y provisiones en ruta
también pueden suspenderla. Las interrupciones encadenadas comparten un intervalo;
no reconstruyen el plan ni consumen pasos. Dos segundos sin causas activas
permiten revalidar y continuar.

El tiempo suspendido desplaza una sola vez los plazos y las referencias de
progreso. El tiempo efectivo queda detenido. Una observación antigua no hace
retroceder el reloj ni contabiliza dos veces una pausa. Al retomar se recalcula
la referencia de distancia tras el desvío, conservando el tiempo activo ya
consumido. La suspensión no renueva presupuestos por sí sola.

Un objetivo explícito de descanso se ejecuta mientras duerme: debe recuperar
sueño, energía y salud. Su progreso real renueva el presupuesto. El sueño no
detiene hambre, sed, temperatura, física, daño ni detección de amenazas.

Las decisiones equivalentes conservan el plan aunque cambien sus etiquetas o
su explicación. Una respuesta tardía de Qwen tampoco puede volver a ejecutar
un prefijo ya completado. Un objetivo realmente bloqueado sigue fallando;
el motor local puede continuar con pasos viables o adoptar otra decisión.
Un plan con pasos fallidos termina como parcial/fallido, nunca como éxito completo.

Se corrigió además una interferencia reproducida en la supervivencia nocturna:
sin luz, combustible ni refugio próximo, `need_light` podía impedir la marcha
por frío que ya existía. Esa rama ahora utiliza el mismo refugio de emergencia
de mayor alcance y, si no hay alternativa, la marcha térmica existente.
El agotamiento letal conserva la vía de sueño. El combate se atiende antes
de entrar en esta rama; no se cambiaron armas, alcance, daño ni reglas de LOS.

La marcha para calentarse comprueba el trayecto completo: un destino seco
ya no permite cruzar repetidamente una charca y volver a empaparse. El muestreo
se hace al elegir un tramo corto, no cada frame.

Al enfriarse, el NPC atiende primero al fuego que tiene al lado, aunque
recuerde otro propio distante. Fuera del anillo termina de recuperarse antes
de volver a tareas del campamento; la espera no bloquea una amenaza inmediata.
Dormir y despertar comparten el umbral de calor, evitando despertarse y volver
a dormirse dentro de la misma emergencia. La comodidad térmica por sí sola
no mantiene suspendida una misión ni hace volver al fuego a un viajero sano.

## Qué constituye éxito

| Objetivo | Evidencia exigida |
| --- | --- |
| Equiparse en la base militar | Arma intacta y utilizable: arma de fuego con munición compatible, arco con flechas o hacha/cuchillo de acero. Piedra, arma rota y rifle vacío no sirven. |
| Buscar aliado | Aliado existente, vivo, socialmente válido y encuentro real a distancia y altura adecuadas. Su destino se actualiza como máximo cada tres segundos, tras moverse más de cuatro metros. |
| Cazar | Baja de presa atribuida al propio bot; si la finalidad es alimento/carne, también debe obtener carne. |
| Recolectar | Alimento adquirido/consumido o necesidad alimentaria satisfecha. Agua y recursos irrelevantes no acreditan comida. |
| Buscar agua | Agua adquirida o hidratación suficiente. |
| Saquear | Adquisición real. Una finalidad específica exige la categoría correspondiente; munición, ropa y herramientas deben ser utilizables en el inventario. |
| Explorar | Destino fijado, proximidad, altura y visita registrada cuando el paso representa un POI. |
| Descansar | Sueño mayor de 78, energía al menos 65 y salud mayor de 85; llegada al lugar de descanso cuando está definido. |
| Volver | Proximidad y altura correctas del hogar válido. |
| Preparar campamento | En las misiones nuevas debe existir el refugio o fuego requerido; una estructura destruida después de iniciar el paso no acredita éxito. |

El campo opcional `purpose` diferencia la finalidad; las directivas antiguas
siguen siendo legibles. Una incursión mantiene el destino conocido mientras
sea válido y no acredita éxito simplemente por visitarlo.
Los requisitos del hogar se comprueban antes de acreditar llegada o recuperación:
alcanzar las antiguas coordenadas de un hogar perdido no evita esa validación.

## Monitor y ejemplos

La API y el archivo de estado siguen siendo los existentes. `planning` añade:

- Objetivo estratégico y del paso, acción estratégica y actividad actual.
- Estado, origen, prioridad, destino, paso/total y cola pendiente.
- Tiempo efectivo, suspensión acumulada y duración de la interrupción actual.
- Motivos y prioridad de interrupción, hora de inicio y estado de reanudación.
- Evidencia, último objeto, último resultado terminal, causa e historial.
- Planes iniciados/completados/fallidos/cancelados, pasos, suspensiones,
  reanudaciones, bloqueos reales, plazos protegidos, tiempo medio, descanso
  suspendido y consultas realmente omitidas.

Se mantienen mapa, inventario, memoria, personalidad, relaciones, equipos,
conversaciones y estadísticas previas de IA y rendimiento. El historial tiene
un máximo de 48 eventos por NPC. Los cambios repetidos sin transición no generan
un evento cada frame. El sondeo web conserva su intervalo de dos segundos,
protección contra solapamientos, pausa al ocultarse y comparación de snapshots.
Un servidor anterior muestra que aún no ofrece esa telemetría.

Ejemplos observados en las pruebas y renderizados por las páginas reales:

1. Carlos: misión de equipamiento `RUNNING`, paso 1/3.
2. `SUSPENDED`, motivo dormir, ocho horas suspendidas y cero tiempo efectivo adicional.
3. Sed → combate → heridas, conservando identidad, destino y los dos pasos pendientes.
4. `RUNNING`, evento «Plan reanudado».
5. Piedra: `PENDING`, equipamiento insuficiente. Rifle vacío: también pendiente.
6. Fusil con munición: evidencia satisfecha; paso siguiente de regreso.
7. Regreso y recuperación completados: resultado terminal conservado en el historial.

No se muestran prompts, razonamiento privado, claves ni credenciales.
Las páginas escapan los textos recibidos. Las capturas locales proceden de
snapshots producidos por Godot en el escenario de regresión; no son datos
de producción ni se publican como `status.json` real.

## Compatibilidad

Se conservan los cuatro personajes, modelos, proveedores, Qwen como asesor,
Godot como ejecutor, ciclo horario, relaciones, equipos, memoria y aprendizaje.
No hay GOAP ni cambios nativos. La ruta histórica `user://` no cambia.

Los nuevos campos de memoria son opcionales. `pending_goals` conserva su formato,
con metadatos `_runtime` opcionales en el primer paso pendiente. Persisten
identidad, índice, totales y destino, sin guardar relojes absolutos de proceso.
Una instancia nueva ha reanudado desde disco el segundo paso de un plan,
sin repetir el equipamiento ya conseguido. También se conserva el aliado elegido,
aunque otro se encuentre más cerca al reiniciar. Al morir/reaparecer se abandona
el plan que llevó a la muerte; el arranque normal de sesión puede revalidarlo.
La comprobación incluye datos legados sin los nuevos campos y guardado/lectura
reales de memoria en un archivo de prueba. No se ha probado cada partida
histórica ni se ha modificado el formato de las partidas de jugadores.

## Verificación y limitaciones

La comprobación final de sintaxis con Godot 4.7 no produjo errores de parseo.
Los registros están en `build/tmp/phase1-*.log`.

| Prueba ejecutada | Resultado final |
| --- | --- |
| BotPlanContinuityRegression | 92 comprobaciones, 0 fallos |
| BotPlanReliabilityRegression | 0 fallos |
| BotGoalConsistencyRegression | 0 fallos |
| BotUtilityRegression | 0 fallos |
| BotDecisionRecoveryRegression | 0 fallos |
| BotLearningRegression | 30 comprobaciones, 0 fallos |
| BotCombatMovementRegression | 86 comprobaciones, 0 fallos |
| BotSleepNeedsRegression | 0 fallos |
| SurvivorBotsAndCombatRegression | 867 comprobaciones, 0 fallos |
| BotNightSurvivalSimRegression | 19 escenarios, 0 fallos; 345,5 s de ejecución |
| BotDaySurvivalSimRegression | 12 escenarios, 0 fallos; 378,4 s de ejecución |
| BotMonitorPollingRegression | Mapa, autoencuadre y sondeo: 0 fallos |
| BotPlanMonitorRegression | Telemetría de Godot, ES/EN: 0 fallos |
| BotPlanMonitorBrowser | Ambas páginas, cinco estados, sondeo real: 0 fallos y 0 errores JS |
| BotPlanPerformanceRegression | 0 fallos |

La continuidad cubre además combate y heridas encadenadas, varias pausas,
sed, emergencias de los cuatro NPC, respuesta tardía y reformulada de Qwen,
bloqueo real, cancelación, resultados parciales y reanudación desde disco.

El escenario S17 se ejecutó antes de corregir el bloqueo por frío: **1 fallo**.
Después de la corrección: **0 fallos**, con movimiento real, misión suspendida
y sin crear provisiones. S18 reprodujo la entrada al agua durante la marcha
térmica (**3 entradas antes, ninguna después**). S19 reprodujo dos fallos del
calor/sueño y dos del regreso innecesario a una fogata; las comprobaciones
focalizadas pasan después de las correcciones, incluido movimiento físico
hacia el destino estratégico.

S1 verifica 8,6 horas con Elena, Carlos, Kael y Ataulfo vivos, dormidos durante
la noche y conservando sus misiones. Después ejecuta el despertar y la
recuperación con estadísticas reales, sin rellenarlas, hasta observar
`RUNNING` con la misma identidad, paso y regreso pendiente. El período de
revalidación se mide con tiempo monotónico real.

Se corrigieron contratos de prueba que aceptaban visitar un POI como botín o
la antigua posición de un aliado como encuentro. También se aislaron estados
residuales de colas, refugios, formación y estadísticas vitales autoritativas.
El escenario de camuflaje parte ahora de un solar validado y sin tareas
residuales del respawn aleatorio, evitando una cascada de coordenadas inválidas
si no se había construido el refugio. La prueba de oído volvió a colocar
al observador a los ocho metros que afirmaba comprobar. El test del mapa activa
explícitamente el autoencuadre, preservando la vista mundial por defecto.

El día completo presentó muertes por hipotermia tanto en la referencia
`f1e1748` como durante el desarrollo. Una traza de posición, temperatura y
humedad identificó el cruce repetido de agua durante `freeze_march`.
Tras corregir el trayecto de recuperación, la simulación diurna completa
terminó con **0 errores**, sin reducir sus aserciones ni alterar la temperatura.
El escenario nocturno S6 también expuso el ciclo de despertar/dormir junto
a un fuego ignorado por recordar otro distante; tras corregirlo, la prueba
aislada terminó con Elena viva, salud 100 y temperatura 36,87 °C.
La ejecución final conjunta de los 19 escenarios también pasó.

Estas simulaciones aceleran el reloj de prueba y usan mundos aislados;
algunas simplifican locomoción y otras comprueban navegación/combate reales.
No equivalen a una prueba multijugador prolongada en el mundo de producción.
Las pruebas generales conservan algunos avisos del renderizador headless y de
recursos al salir; el JSON inválido provocado por los tests también genera un
mensaje esperado. Los resultados deben distinguir aserciones, errores de script
y esos avisos.

No quedan fallos de aserciones ni errores de script en la matriz final ejecutada.
Quedan pendientes la exportación/publicación autorizadas y su verificación en
producción; el microbenchmark y las simulaciones locales no sustituyen esa
comprobación. Las capturas generadas por el navegador están en
`build/tmp/phase1-monitor-<idioma>-<estado>.png`.

## Rendimiento y API

`BotPlanPerformanceRegression` compara, en el mismo proceso, el gestor original
de `f1e1748` compilado en memoria y el actual con los mismos cuatro bots.
Mide cinco rondas de 8.000 revisiones y 25 snapshots completos por versión.
Las cifras finales se guardan en `build/tmp/phase1-performance.json`.
Es un microbenchmark local, no una medida de latencia de red ni GPU.

| Medición | Base | Después |
| --- | ---: | ---: |
| Revisión por bot | 2,748 µs | 14,433 µs |
| Snapshot completo | 0,719 ms | 0,814 ms |
| Tamaño del snapshot | 21.586 bytes | 26.274 bytes |

Coste adicional medido: unos **46,7 µs para los cuatro bots** por revisión
y **0,095 ms por snapshot**. El payload aumenta 4.688 bytes. No se añadió
planificación compleja por frame, espera remota en el hilo principal ni
reconstrucción continua de rutas.

Se conservan cola, caché, límites, prioridades, modelos de respaldo y backoff.
No se solicita una decisión por dormir o por cada interrupción. Las respuestas
tardías no reinician pasos y la indisponibilidad de API sigue usando el motor local.
El ciclo de continuidad no realizó llamadas remotas adicionales. El prompt
incorpora el propósito opcional y excluye los metadatos internos de reanudación,
para no aumentar sus tokens con relojes y checkpoints. No cambian los proveedores.
El consumo real de producción no se ha medido porque esta fase no se ha desplegado.

## Publicación pendiente

Se requiere una autorización posterior para publicar. El procedimiento está
en `scripts/bot_ai/README.md`: servidor exportado y verificado según `AGENTS.md`,
ambas páginas y `bot_plans.js` juntos, y comprobación del build vivo,
`bots[].planning` y del navegador público. Hasta entonces,
`https://descargas.cronicasdesupervivencia.com/bots/index.html` conserva su versión
anterior.

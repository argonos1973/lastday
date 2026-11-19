/* Server planning telemetry only. Missing fields mean an older server. */
(function (root) {
  "use strict";
  const text = {
    es: {
      title: "Continuidad de la misión", none: "El servidor todavía no publica estados de planificación.",
      idle: "Sin plan estratégico activo", goal: "Objetivo", stepGoal: "Objetivo del paso",
      action: "Acción estratégica", activity: "Actividad actual", step: "Paso", of: "de",
      source: "Origen", priority: "Prioridad", pending: "Pasos pendientes", target: "Destino",
      interruptionPriority: "Prioridad de interrupción", suppressed: "Consultas omitidas durante suspensión",
      active: "Ejecución efectiva", paused: "Suspensión acumulada", reason: "Interrupciones",
      since: "Desde", duration: "Duración actual", waiting: "Esperando recuperación y revalidación",
      resumed: "Objetivo revalidado; misión reanudada", evidence: "Resultado del paso",
      last: "Último plan terminado", item: "Último objeto", history: "Historial de planificación",
      metrics: "Estadísticas de planificación", started: "Iniciados", completed: "Completados",
      failed: "Fallidos", cancelled: "Cancelados", steps: "Pasos", suspensions: "Suspensiones",
      resumptions: "Reanudaciones", blocks: "Bloqueos reales", avoided: "Plazos protegidos por suspensión",
      average: "Tiempo efectivo medio", sleep: "Descanso con misión suspendida", local: "Decisiones locales",
      qwen: "Respuestas Qwen válidas", api: "Errores API / respuestas inválidas", night: "Consultas nocturnas omitidas",
      RUNNING: "En marcha", SUSPENDED: "Suspendido", COMPLETED: "Completado", FAILED: "Fallido",
      CANCELLED: "Cancelado", PENDING: "Pendiente", SATISFIED: "Objetivo satisfecho"
    },
    en: {
      title: "Mission continuity", none: "The server does not publish planning states yet.",
      idle: "No active strategic plan", goal: "Goal", stepGoal: "Step goal",
      action: "Strategic action", activity: "Current activity", step: "Step", of: "of",
      source: "Source", priority: "Priority", pending: "Remaining steps", target: "Destination",
      interruptionPriority: "Interruption priority", suppressed: "Queries skipped during suspension",
      active: "Active execution", paused: "Total suspension", reason: "Interruptions",
      since: "Since", duration: "Current duration", waiting: "Waiting for recovery and revalidation",
      resumed: "Objective revalidated; mission resumed", evidence: "Step result",
      last: "Last finished plan", item: "Last item", history: "Planning history",
      metrics: "Planning statistics", started: "Started", completed: "Completed",
      failed: "Failed", cancelled: "Cancelled", steps: "Steps", suspensions: "Suspensions",
      resumptions: "Resumptions", blocks: "Real blocks", avoided: "Deadlines protected by suspension",
      average: "Mean active time", sleep: "Rest with mission suspended", local: "Local decisions",
      qwen: "Valid Qwen responses", api: "API errors / invalid responses", night: "Night queries skipped",
      RUNNING: "Running", SUSPENDED: "Suspended", COMPLETED: "Completed", FAILED: "Failed",
      CANCELLED: "Cancelled", PENDING: "Pending", SATISFIED: "Objective satisfied"
    }
  };
  const reasons = {
    combat: ["Combate", "Combat"], escape: ["Huida o refugio ante amenaza", "Escape or cover"],
    cold: ["Hipotermia", "Hypothermia"], heat: ["Temperatura peligrosa", "Dangerous temperature"],
    bleeding: ["Heridas y sangrado", "Wounds and bleeding"], exhaustion: ["Agotamiento", "Exhaustion"],
    hunger: ["Hambre urgente", "Urgent hunger"], thirst: ["Sed urgente", "Urgent thirst"],
    sleep: ["Dormir / descanso nocturno", "Sleep / overnight rest"], recovery: ["Recuperación", "Recovery"],
    night_refuge: ["Buscar refugio para la noche", "Seeking overnight refuge"],
    session_revalidated: ["Misión guardada revalidada al iniciar sesión", "Saved mission revalidated at session start"],
    supplies: ["Provisiones en ruta", "Supplies en route"], objective_revalidated: ["Objetivo revalidado", "Objective revalidated"],
    functional_weapon: ["Arma funcional conseguida", "Functional weapon obtained"],
    insufficient_equipment: ["Equipamiento insuficiente", "Insufficient equipment"],
    ally_met: ["Encuentro real con aliado", "Ally actually met"], ally_not_met: ["Aliado aún no encontrado", "Ally not met yet"],
    ally_unavailable: ["Aliado muerto o ya no válido", "Ally dead or no longer valid"],
    home_reached: ["Refugio alcanzado", "Home reached"], home_pending: ["Regreso pendiente", "Return pending"],
    home_unavailable: ["Refugio perdido", "Home unavailable"], recovered: ["Recuperación verificada", "Recovery verified"],
    recovery_pending: ["Falta recuperar sueño, energía o salud", "Sleep, energy or health still need recovery"],
    need_satisfied: ["Necesidad satisfecha", "Need satisfied"], useful_food_pending: ["Falta alimento útil", "Useful food pending"],
    hunt_result: ["Resultado de caza verificado", "Hunt result verified"], prey_or_meat_pending: ["Falta presa propia o carne", "Own prey or meat pending"],
    useful_loot: ["Botín adecuado conseguido", "Requested loot obtained"], requested_loot_pending: ["Falta el botín solicitado", "Requested loot pending"],
    destination_visited: ["Destino correcto visitado", "Correct destination visited"], destination_pending: ["Visita pendiente", "Visit pending"],
    camp_ready: ["Campamento preparado", "Camp ready"], camp_pending: ["Campamento pendiente", "Camp pending"],
    zone_left: ["Zona peligrosa abandonada", "Danger zone left"], danger_zone: ["Sigue en zona peligrosa", "Still in danger zone"],
    actor_dead: ["NPC muerto", "NPC died"], timeout: ["Presupuesto activo agotado", "Active budget exhausted"],
    no_progress: ["Sin progreso durante ejecución activa", "No progress during active execution"],
    nav_blocked: ["Ruta bloqueada", "Route blocked"], stuck_timeout: ["Bloqueo confirmado", "Block confirmed"],
    replaced_by_priority: ["Sustituido por mayor prioridad", "Replaced by higher priority"],
    strategic_review: ["Objetivo modificado en revisión estratégica", "Goal changed by strategic review"],
    precondition_failed: ["Requisito perdido", "Precondition lost"], plan_completed: ["Todos los pasos cumplidos", "All steps completed"],
    plan_partial: ["Plan terminado con pasos fallidos", "Plan ended with failed steps"],
    local_task_stalled: ["Reintento local: tarea de recuperación bloqueada", "Local retry: recovery task stalled"],
    decision_accepted: ["Decisión aceptada", "Decision accepted"]
  };
  const events = {
    plan_started: ["Plan iniciado", "Plan started"], decision_local: ["Decisión local", "Local decision"],
    decision_qwen: ["Decisión Qwen", "Qwen decision"], decision_memory: ["Plan de memoria", "Plan from memory"],
    step_started: ["Paso iniciado", "Step started"], step_completed: ["Paso completado", "Step completed"],
    step_failed: ["Paso fallido", "Step failed"], plan_suspended: ["Plan suspendido", "Plan suspended"],
    interruption_changed: ["Emergencia encadenada", "Chained emergency"], plan_resumed: ["Plan reanudado", "Plan resumed"],
    plan_completed: ["Plan completado", "Plan completed"], plan_failed: ["Plan fallido", "Plan failed"],
    plan_cancelled: ["Plan cancelado / objetivo modificado", "Plan cancelled / goal changed"],
    loot_result: ["Botín evaluado", "Loot evaluated"], recovery_retry: ["Recuperación revisada", "Recovery reviewed"]
  };
  const goals = {
    gear_up_at_military_base:["Conseguir equipamiento en la base militar","Find equipment at the military base"],
    secure_food_safely:["Conseguir alimento con seguridad","Find food safely"],
    hunt_prey_for_meat_and_pelts:["Cazar para obtener carne y pieles","Hunt for meat and pelts"],
    return_after_supplies:["Volver con las provisiones","Return with supplies"],
    explore_new_locations:["Explorar nuevos lugares","Explore new places"],
    recover_health_in_refuge:["Recuperarse en el refugio","Recover at home"],
    regroup_with_trusted_ally:["Reunirse con un aliado","Meet an ally"],
    dominate_high_tier_loot:["Buscar equipo de calidad","Find useful equipment"],
    build_and_defend_camp:["Preparar el campamento","Prepare the camp"],
    explore:["Explorar","Explore"], scavenge:["Saquear","Scavenge"], hunt:["Cazar","Hunt"],
    forage:["Recolectar provisiones","Gather supplies"], rest:["Descansar","Rest"],
    return_home:["Volver al refugio","Return home"], seek_ally:["Buscar aliado","Seek ally"],
    avoid_zone:["Evitar zona peligrosa","Avoid a dangerous area"], fortify_camp:["Fortificar campamento","Fortify camp"],
    freeze_march:["Caminar para entrar en calor","Walking to warm up"],
    fire_rescue:["Buscar o encender fuego","Seeking or lighting a fire"],
    warm_up:["Acercarse al calor","Moving toward warmth"], cool_off:["Alejarse del calor","Moving away from heat"],
    firstaid:["Atender heridas","Treating wounds"], predator:["Responder a un animal","Responding to an animal"],
    foe:["Responder a un enemigo","Responding to an enemy"], cover:["Buscar cobertura","Taking cover"],
    flee:["Huir","Fleeing"], search_foe:["Buscar la amenaza perdida","Searching for a lost threat"],
    eat:["Comer","Eating"], drink:["Beber","Drinking"], farm:["Cultivar","Farming"],
    cook:["Cocinar","Cooking"], gut:["Recoger carne de la presa","Harvesting prey"],
    rest_home:["Descansar en el refugio","Resting at home"], water_escape:["Salir del agua","Leaving the water"],
    night_supplies:["Resolver provisiones nocturnas","Handling overnight supplies"],
    need_light:["Preparar luz o refugio","Preparing light or shelter"],
    craft:["Fabricar","Crafting"], build:["Construir","Building"], team:["Seguir al equipo","Following the team"],
    loot:["Recoger botín","Collecting loot"], settle:["Preparar el campamento","Setting up camp"],
    military:["Base militar","Military base"], city:["Ciudad","City"], house:["Casa","House"],
    wild:["Campo","Wilderness"], camp:["Campamento","Camp"], ally:["Aliado","Ally"]
  };
  const escape = value => String(value ?? "").replace(/[&<>"']/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
  const seconds = value => {
    const n = Math.max(0, Math.floor(Number(value) || 0));
    return `${Math.floor(n / 3600)}h ${Math.floor(n % 3600 / 60)}m ${n % 60}s`;
  };
  function render(bot, lang = "es") {
    const en = lang === "en", t = text[en ? "en" : "es"], idx = en ? 1 : 0;
    const label = (map, key) => escape(map[key] ? map[key][idx] : key);
    const why = value => String(value || "").split(",").map(k => label(reasons, k)).join(" · ");
    const date = value => value ? escape(new Date(Number(value) * 1000).toLocaleString(en ? "en-GB" : "es-ES")) : "—";
    const badge = state => {
      const s = ["RUNNING", "SUSPENDED", "COMPLETED", "FAILED", "CANCELLED", "PENDING", "SATISFIED"].includes(state) ? state : "PENDING";
      const color = {RUNNING:"#4ecdc4",SUSPENDED:"#f7b731",COMPLETED:"#78c98b",FAILED:"#ff7675",CANCELLED:"#aab4c4"}[s] || "#aab4c4";
      return `<span class="plan-state" data-plan-state="${s}" style="color:${color};font-weight:600">${s} · ${t[s]}</span>`;
    };
    const line = (name, value) => `<div class="meta-line"><b>${escape(name)}:</b> ${value}</div>`;
    if (!bot.planning) return `<div class="meta-line plan-legacy">${t.none}</div>`;
    const p = bot.planning.plan || {}, m = bot.planning.metrics || {}, a = bot.ai_stats || {}, last = bot.planning.last_result || {};
    let out = `<section class="plan-panel"><div class="section-label">${t.title}</div><div class="decision-box">`;
    if (p.id) {
      out += badge(p.state) + line(t.goal, label(goals,p.goal)) + line(t.stepGoal, label(goals,p.step_goal || p.goal));
      out += line(t.action, label(goals,p.action)) + line(t.activity, bot.sleeping ? (en ? "Sleeping" : "Durmiendo") : label(goals,bot.planning.activity || bot.act || "—"));
      out += line(t.step, `${Number(p.step) || 1} ${t.of} ${Number(p.total_steps) || 1}`) + line(t.source, escape(p.source)) + line(t.priority, `${Number(p.priority) || 0}/5`);
      out += line(t.target, label(goals,p.target) + ((p.destination || []).length ? ` (${p.destination.map(n=>Number(n).toFixed(1)).join(", ")})` : ""));
      out += line(t.pending, (p.remaining || []).map(s=>label(goals,s.action) + " → " + label(goals,s.target)).join(" · ") || "—");
      out += line(t.active, seconds(p.active_seconds)) + line(t.paused, seconds(p.suspended_seconds));
      if (p.state === "SUSPENDED") {
        out += line(t.reason, (p.reasons || []).map(why).join(" · ")) + line(t.since, date(p.suspended_at));
        out += line(t.interruptionPriority, `${Number(p.interruption_priority)||0}/100`);
        out += line(t.duration, seconds(p.interruption_seconds)) + `<div class="meta-line">${t.waiting}</div>`;
      } else if (p.resume_status === "resumed") out += `<div class="meta-line">${t.resumed}</div>`;
      if (p.evidence && p.evidence.reason) {
        out += line(t.evidence, badge(p.evidence.complete ? "SATISFIED" : "PENDING") + " · " + why(p.evidence.reason));
        if (p.evidence.last_item) out += line(t.item, escape(p.evidence.last_item));
      }
    } else out += `<div class="meta-line">${t.idle}</div>`;
    if (last.state) out += line(t.last, badge(last.state) + ` · ${label(goals,last.goal)} · ${why(last.reason)} · ${date(last.time)}`);
    out += `</div><details class="sec" data-sec id="sec_${Number(bot.bot_id)}_plans"><summary class="section-label">${t.history}</summary>`;
    out += (bot.planning.history || []).slice(-48).reverse().map(e =>
      `<div class="meta-line plan-event">${date(e.time)} · <b>${label(events,e.type)}</b> · ${label(goals,e.goal)} · ${t.step} ${Number(e.step)||1}${e.step_goal && e.step_goal !== e.goal ? " · "+label(goals,e.step_goal):""}${e.reason ? " · "+why(e.reason):""}${e.item ? " · "+escape(e.item):""}${e.result ? " · "+badge(e.result):""}</div>`).join("");
    out += `</details><details class="sec" data-sec id="sec_${Number(bot.bot_id)}_planstats"><summary class="section-label">${t.metrics}</summary>`;
    for (const [name,key] of [[t.started,"plans_started"],[t.completed,"plans_completed"],[t.failed,"plans_failed"],[t.cancelled,"plans_cancelled"],[t.suspensions,"suspensions"],[t.resumptions,"resumptions"],[t.blocks,"real_blocks"],[t.avoided,"suspension_deadlines_avoided"]]) out += line(name, Number(m[key])||0);
    out += line(t.steps, `${Number(m.steps_completed)||0} ✓ / ${Number(m.steps_failed)||0} ✗`);
    out += line(t.average, m.plans_finished ? seconds(m.finished_active_seconds/m.plans_finished) : "—");
    out += line(t.sleep, seconds(m.sleep_suspended_seconds));
    out += line(t.local, Number(a.local_decisions)||0) + line(t.qwen, Number(a.qwen_ok)||0);
    out += line(t.api, `${Number(a.http_errors)||0} / ${Number(a.qwen_invalid)||0}`) + line(t.night, Number(a.night_skipped)||0);
    out += line(t.suppressed, Number(m.suspended_queries_skipped)||0);
    return out + "</details></section>";
  }
  root.BotPlans = {render, seconds};
  if (typeof module !== "undefined") module.exports = root.BotPlans;
})(typeof globalThis === "object" ? globalThis : this);

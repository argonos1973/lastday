/* Run after BotPlanContinuityRegression.gd: use actual serialized telemetry. */
const fs = require("fs");
const assert = require("assert");
const vm = require("vm");
const {render} = require("../web/bot_plans.js");
const states = JSON.parse(fs.readFileSync("build/tmp/phase1-monitor-states.json", "utf8"));
const carlos = state => state.bots.find(b => b.bot_id === 902);
for (const lang of ["es", "en"]) {
  for (const state of states) {
    const b = carlos(state), html = render(b, lang);
    assert(html.includes("plan-panel"));
    assert(!html.includes("undefined") && !html.includes("NaN"), `${lang} ${state.test_label}`);
    if (b.planning.plan.id) assert(html.includes(`data-plan-state="${b.planning.plan.state}"`));
  }
  assert(render(carlos(states.find(s=>s.test_label==="sleeping")),lang).includes("SUSPENDED"));
  assert(render(carlos(states.find(s=>s.test_label==="resumed")),lang).includes(lang==="es"?"Plan reanudado":"Plan resumed"));
  const legacy = {...carlos(states[0])}; delete legacy.planning;
  assert(render(legacy,lang).includes("plan-legacy"));
  const hostile = JSON.parse(JSON.stringify(carlos(states[0])));
  hostile.planning.plan.goal = '<img src=x onerror="alert(1)">';
  assert(!render(hostile,lang).includes("<img"), "escaped telemetry");
  const html = fs.readFileSync(`tools/web/bot_monitor${lang==="en"?"_en":""}.html`,"utf8");
  for (const match of html.matchAll(/<script>([\s\S]*?)<\/script>/g)) new vm.Script(match[1]);
  assert(html.includes('setInterval(pollStatus, 2000)'));
  for (const section of ["renderMap", "renderChat", "renderBots", "food_eaten", "relationships", "inventory", "ai_stats", "renderHeader"]) assert(html.includes(section), section);
}
const sleeping = carlos(states.find(s=>s.test_label==="sleeping"));
const resumed = carlos(states.find(s=>s.test_label==="resumed"));
assert.equal(sleeping.planning.plan.id,resumed.planning.plan.id);
assert.equal(sleeping.planning.plan.step,resumed.planning.plan.step);
assert(sleeping.planning.plan.suspended_seconds>=8*3600);
assert(sleeping.planning.plan.active_seconds<2);
const all = states.flatMap(s=>carlos(s).planning.history);
for(const type of ["plan_started","plan_suspended","plan_resumed","step_completed","plan_completed","plan_failed","plan_cancelled","loot_result"]) assert(all.some(e=>e.type===type),type);
console.log("BotPlanMonitorRegression errors=0 (ES/EN, real Godot telemetry)");

# Planning lifecycle

`SurvivorBotManager` remains the authoritative world/reactive coordinator. These
modules operate on its existing `b.ai_directive`; there is no second planner,
action queue, navigation engine, or model provider.

- `BotPlanManager`: accepts decisions through the existing parser, preserves
  objective inertia, advances steps, owns execution clocks and terminal results,
  suspends/resumes, and invokes the existing local fallback on real failure.
- `BotGoalValidator`: resolves success purposes, checks real ammunition and
  durability, tracks live allies, validates homes and checks outcome evidence.
- `BotInterruptionManager`: reads the existing reactive state and returns ordered
  reason codes. It also validates short thermal recovery legs, so a dry
  destination cannot justify repeatedly crossing water while hypothermic.
  It never executes combat, navigation, sleep, healing or eating.
- `BotPlanDiagnostics`: bounded structured events, counters and JSON-safe monitor
  projection. It contains no prompts, private model reasoning or credentials.

Dependencies flow from the coordinator into these modules; `BotPlanManager`
also uses the three smaller modules. They never preload the coordinator. World queries are
supplied by the coordinator using its existing methods, allowing isolated tests.

## Single active plan

The existing directive carries `plan_id`, `state`, `step_index`, `total_steps`,
`active_ms`, `suspended_ms`, `interruptions` and `evidence`. Its existing
`_remaining_steps`, `_dest_pos`, `_dest_id`, `_ev0` and `_plan_root` are reused.
Each accepted step keeps the same plan ID. The root objective is `_plan_goal`.

`RUNNING` becomes `SUSPENDED` for incompatible sleep, combat/escape, urgent
survival or an active local resupply job. All simultaneous reasons share one
interval. Reason changes are events, not new plans. Two seconds without an
interruption permit revalidation and resumption. The reactive tick and vital
stats always continue. A rest objective executes while sleeping: real recovery
renews its budget; inactivity without recovery remains detectable.

Only elapsed monotonic suspension time shifts deadlines and progress timestamps.
Reaffirming an equivalent decision does not replenish deadlines. Resumption
rebases the distance after a detour without erasing previously spent active time.
An unresolved local recovery task gets a bounded rescan after three minutes
without measured movement, activity or vital changes. It cannot silently hide
its blockage in the monitor.

The existing no-light supply branch can use the ordinary emergency refuge
radius and, when no heat/refuge is available, the existing warming march.
Preparing light must not block thermal recovery. Warming-leg sampling happens
only when selecting the next short leg (at most six candidates), not every
frame; an already wet actor may leave water without entering deeper water.
Routine `warm_up`/`cool_off` positioning alone does not suspend strategy:
actual thermal danger controls that pause. The existing reactive loop finishes
cooling outside the fire ring before returning to camp chores, reacts to the
nearby fire even if another owned fire is known, and does not recall a healthy
daytime expedition solely for comfort. Sleep admission and heat wake-up share
`GameConst.BOT_HEAT_ALERT_TEMP`.

`COMPLETED`, `FAILED` and `CANCELLED` are retained in `plan_history` (48 events per
NPC) and `last_plan_result`, even after the next plan starts. Replacing an accepted
goal records cancellation; a temporary interruption does not train a failure.
Plans ending after skipped failed steps are recorded as failed/partial, never
as an unqualified success.

## Success and backward compatibility

An optional `purpose` field distinguishes general loot, gear, food, water, ammo,
clothing, tools, weapons and meat. Known legacy goal names also resolve purposes.
Unknown purposes are rejected. `gear_up_at_military_base` always requires a
functional gun with matching ammo, an intact bow with arrows, or an intact steel
axe/knife, using the existing combat ammo rules. A planned raid chooses a known
military destination. Merely proposing a raid cannot enable its loot filter.

Meeting an ally requires a living, cooperating actor at the actual meeting
distance and height; the destination refreshes at most every three seconds and
only after movement over four metres. Hunting for food requires the bot's own
prey credit plus meat. Water cannot complete a food objective. Exploration checks
the pinned location, height and registered visit for POI-mode plans. Rest requires
actual sleep, energy and health recovery.

Old memory fields and plan formats remain readable. New diagnostics fields are
optional. The existing `pending_goals` first step can carry `_runtime` metadata:
identity, step index, totals, pinned destination and chosen ally identity.
Checkpoint metadata is excluded from the advisor's pending-step context to
avoid unnecessary prompt tokens. No absolute uptime clocks
are persisted. Session boot revalidates and rebases clocks; death/respawn does not
resume the plan that killed the bot. Inventory baselines are fresh after boot
because the dedicated world is per session. No save or network schema is removed.

## Monitor and publication

The existing debug snapshot and `status.json` add one `planning` projection.
The ES/EN pages load `tools/web/bot_plans.js`, keeping their tactical map,
inventory, relations, memories, chat and original API/performance statistics.
Polling remains at two seconds with overlap/visibility/unchanged-data guards.
Older servers show an explicit “planning telemetry unavailable” message.
Events show structured decisions and observed outcomes only.

Nothing in this phase deploys itself. A later authorized publication must:

1. Export and deploy the tested dedicated server following `AGENTS.md` (stamp,
   sequential export, native library, service-managed restart, new world).
2. Publish `bot_monitor.html` as the bot site's `index.html`,
   `bot_monitor_en.html` as `index_en.html`, and `bot_plans.js` beside both.
3. Verify the live build and `status.json` contains `bots[].planning`, then open
   both public pages and verify the script loads and transitions appear.

Do not claim the public monitor is updated until these checks are performed.

## Validation commands

Use the repository Godot executable, `--headless --path . --script` and an
absolute script path. `BotPlanContinuityRegression.gd` exercises real manager
transitions with the existing isolated world, all four NPCs, sleep physiology,
goals, chained emergencies, persistence, API suppression and telemetry. Its
clock injection tests eight hours in milliseconds without changing the game
clock. It writes real serialized test snapshots under `build/tmp/`.

`node tools/debug/BotPlanMonitorRegression.cjs` consumes those snapshots.
`BotPlanMonitorBrowser.cjs` uses Playwright (set `PLAYWRIGHT_MODULE` and optionally
`CHROME_PATH`), serves the two actual pages locally, and checks natural polling,
all states, four cards, the map, JS errors and screenshots. Test fixtures are
never published as production `status.json`.

`BotPlanPerformanceRegression.gd` compiles the baseline manager from `f1e1748` in
memory, compares watchdog and full status generation in the same process with
the same four bots, and writes measurements under `build/tmp/`.

`BotNightSurvivalSimRegression.gd` covers the full night and actual dawn
resumption of all four NPCs. Its `--only-s1`, `--only-s17`, `--only-s18` and
`--only-s19` user arguments isolate the full cycle and thermal recovery cases
(place them after `--`). S19 checks actual travel toward the strategic target
after recovery, not only a plan-state transition.

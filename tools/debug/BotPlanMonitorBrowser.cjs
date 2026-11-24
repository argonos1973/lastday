/* Optional browser integration, using the same real Godot regression snapshots.
   PLAYWRIGHT_MODULE points at an installed Playwright package. No production writes. */
const fs = require("fs"), path = require("path"), http = require("http"), assert = require("assert");
const {chromium} = require(process.env.PLAYWRIGHT_MODULE || "playwright");
const snapshots = JSON.parse(fs.readFileSync("build/tmp/phase1-monitor-states.json", "utf8"));
let current = snapshots[0], polls = 0;
const server = http.createServer((req,res)=>{
  const name = new URL(req.url,"http://localhost").pathname;
  if(name === "/status.json") {
    polls++;
    res.setHeader("Content-Type","application/json");
    return res.end(JSON.stringify(current));
  }
  const file = {"/": "bot_monitor.html", "/index_en.html":"bot_monitor_en.html", "/bot_plans.js":"bot_plans.js"}[name];
  if(!file) {res.statusCode=404;return res.end();}
  res.setHeader("Content-Type",file.endsWith(".js")?"text/javascript":"text/html");
  res.end(fs.readFileSync(path.join("tools/web",file)));
});
(async()=>{
  await new Promise(resolve=>server.listen(0,"127.0.0.1",resolve));
  const browser = await chromium.launch({headless:true, executablePath:process.env.CHROME_PATH || "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"});
  try {
    const errors=[];
    const page=await browser.newPage({viewport:{width:1440,height:1100}});
    page.on("pageerror",e=>errors.push(e.message));
    for(const [lang,url] of [["es","/"],["en","/index_en.html"]]) {
      current=snapshots[0];
      await page.goto(`http://127.0.0.1:${server.address().port}${url}`);
      await page.waitForSelector('.plan-panel [data-plan-state="RUNNING"]');
      for(const state of snapshots.slice(1)) {
        const before=polls; current=state;
        const b=current.bots.find(b=>b.bot_id===902);
        const status=b.planning.plan.state || b.planning.last_result.state;
        await page.waitForFunction(s=>Array.from(document.querySelectorAll(".plan-panel [data-plan-state]")).some(e=>e.dataset.planState===s),status);
        await page.waitForTimeout(2200); // actual interval, never invoking render manually
        assert(polls>before,"automatic refresh");
        if(state.test_label==="sleeping" || state.test_label==="resumed") {
          const panel = page.locator(".plan-panel").nth(1);
          await panel.scrollIntoViewIfNeeded();
          await panel.screenshot({path:`build/tmp/phase1-monitor-${lang}-${state.test_label}.png`});
        }
      }
      assert(await page.locator("#mapCanvas").count(),"tactical map preserved");
      assert(await page.locator(".plan-panel").count()===4,"all four NPC cards preserved");
      const recent = Array.from({length:8}, (_,i)=>({provider:"groq",model:`model-${i}`,http:200,started:1}));
      current={...current,timestamp:current.timestamp+1,groq:{...current.groq,recent_calls:recent}};
      await page.locator("#callOlder summary").click();
      current={...current,timestamp:current.timestamp+1,groq:{...current.groq,recent_calls:recent.slice(1)}};
      await page.waitForFunction(()=>document.querySelector("#callOlder summary").textContent.includes("(1)"));
      assert(await page.locator("#callOlder").evaluate(el=>el.open),"refresh preserves the expanded call history");
    }
    assert.deepEqual(errors,[],"no browser JavaScript errors");
    console.log("BotPlanMonitorBrowser errors=0 (both languages, real polling, all 5 states)");
  } finally {await browser.close();server.close();}
})().catch(e=>{console.error(e);server.close();process.exitCode=1;});

const fs = require('fs');
const vm = require('vm');
const assert = require('assert');
const html = fs.readFileSync('tools/web/bot_monitor.html','utf8');
const source = html.slice(html.indexOf('let pollInFlight ='),html.indexOf('\npollStatus();',html.indexOf('let pollInFlight =')));
let calls = 0, renders = 0, resolveFetch, listener;
const context = {AbortController, JSON, Date, setTimeout, clearTimeout,
 document:{hidden:false,addEventListener:(_n,fn)=>listener=fn,getElementById:()=>({textContent:''})},
 fetch:()=>{calls++;return new Promise(resolve=>resolveFetch=resolve)},
 renderHeader:()=>renders++,renderSummary:()=>{},renderMap:()=>{},renderChat:()=>{},renderBots:()=>{},restoreChatOpen:()=>{}};
vm.createContext(context);vm.runInContext(source,context);
const response = value => ({ok:true,text:async()=>JSON.stringify(value)});
(async()=>{
 let p=context.pollStatus(); await context.pollStatus();assert.equal(calls,1,'no overlapping fetch');
 resolveFetch(response({timestamp:1}));await p;assert.equal(renders,1);
 p=context.pollStatus();resolveFetch(response({timestamp:1}));await p;assert.equal(renders,1,'unchanged snapshot not redrawn');
 context.document.hidden=true;await context.pollStatus();assert.equal(calls,2,'hidden monitor does not poll');
 context.document.hidden=false;p=context.pollStatus();resolveFetch(response({timestamp:2}));await p;assert.equal(renders,2);
 p=context.pollStatus();resolveFetch({ok:false,status:503});await p;
 p=context.pollStatus();resolveFetch(response({timestamp:2}));await p;assert.equal(renders,3,'successful poll clears previous error');
 console.log('BotMonitorPollingRegression errors=0');
})().catch(e=>{console.error(e);process.exitCode=1});

// Mapa tactico: funciones de vista (zoom/pan/auto-enfoque) extraidas entre
// los marcadores MAPVIEW-PURE y ejecutadas con mapView en el contexto.
const mvSrc = html.slice(html.indexOf('// MAPVIEW-PURE-BEGIN'), html.indexOf('// MAPVIEW-PURE-END'));
assert(mvSrc.includes('function mapGridStep') && mvSrc.includes('function autoMapView') && mvSrc.includes('function makeMapToScreen'), 'map view helpers present');
const mvCtx = { Math, mapView: { cx: 0, cz: 0, halfSpan: 500 }, MAP_PAD: 1.08 };
vm.createContext(mvCtx); vm.runInContext(mvSrc, mvCtx);
const ts = mvCtx.makeMapToScreen(400, 360);
assert.deepEqual(ts(0, 0).map(Math.round), [200, 180], 'vista por defecto reproduce el centro del mapeo clasico');
assert.deepEqual(ts(-500, -500).map(Math.round), [12, 12], 'esquina NO');
assert.deepEqual(ts(500, 500).map(Math.round), [388, 348], 'esquina SE');
assert.equal(mvCtx.mapGridStep(500), 200, 'grid legado a zoom mundo');
assert.equal(mvCtx.mapGridStep(60), 50, 'grid adaptativa a zoom cercano');
const av = mvCtx.autoMapView(800, [[10, 20], [40, 80]]);
assert(Math.abs(av.cx - 25) < 1e-6 && Math.abs(av.cz - 50) < 1e-6, 'auto-enfoque centra a los actores');
assert(av.halfSpan >= 75 && av.halfSpan <= 800 * 1.08, 'auto-enfoque limita el campo visible');
assert.deepEqual(mvCtx.autoMapView(800, []).halfSpan, 800 * 1.08, 'sin actores encuadra el mundo');
// Estructura de controles: rueda, arrastre, doble click y persistencia.
for (const s of ['"wheel"', '"pointerdown"', '"pointermove"', '"dblclick"', 'botMapView', 'botMapAuto', 'mapAutoChk', 'mapZoomIn', 'mapFit'])
  assert(html.includes(s), 'map control present: ' + s);
console.log('BotMonitorMapRegression errors=0');

// Exercise the full renderer: autoMapView alone cannot catch omitted actors.
const mapSource = html.slice(html.indexOf('const MAP_MIN_SPAN'), html.indexOf('const CHAT_KIND'));
const canvasContext = new Proxy({}, {get:(obj,key)=>obj[key] || (()=>{}), set:(obj,key,val)=>(obj[key]=val,true)});
const canvas = {width:400,height:360,clientWidth:400,getContext:()=>canvasContext};
const mapContext = {Math, JSON, Number, String, isFinite, BOT_COLORS:{},
 localStorage:{getItem:()=>null,setItem:()=>{}},
 document:{getElementById:id=>id==='mapCanvas' ? canvas : {}}};
vm.createContext(mapContext);vm.runInContext(mapSource,mapContext);
const aliveBot = {bot_id:901,name:'Bot',hp:100,pos:[10,0,20]};
const human = {id:2,name:'Jugador',pos:[800,0,700]};
mapContext.renderMap({bots:[aliveBot],players:[human]});
assert(vm.runInContext('mapView.cx > 300 && mapView.cz > 300',mapContext), 'auto focus includes a distant online human, not only bots');
mapContext.renderMap({bots:[],players:[human]});
assert.equal(vm.runInContext('mapView.cx',mapContext),800,'a lone human is also centered');
mapContext.renderMap({bots:[aliveBot],players:[{...human,offline:true},{...human,id:3,dead:true}]});
assert.equal(vm.runInContext('mapView.cx',mapContext),10,'disconnected bodies and corpses do not pull auto focus');
vm.runInContext('mapAuto=false;mapView={cx:123,cz:456,halfSpan:80}',mapContext);
mapContext.renderMap({bots:[aliveBot],players:[human]});
assert.equal(vm.runInContext('mapView.cx',mapContext),123,'polling preserves manual pan/zoom');
console.log('BotMonitorActorFramingRegression errors=0');

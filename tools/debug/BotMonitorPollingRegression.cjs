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

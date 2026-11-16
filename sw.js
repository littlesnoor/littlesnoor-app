const C="littlesnoor-v57";
const FILES=["./","index.html","manifest.webmanifest","icon-192.png","icon-512.png","icon-180.png","covers/mulai-lagi-id.jpg","covers/catatan-majelis-id.jpg","covers/planner-2027-id.jpg"];
self.addEventListener("install",e=>{e.waitUntil(caches.open(C).then(c=>c.addAll(FILES)));self.skipWaiting();});
self.addEventListener("activate",e=>{e.waitUntil(caches.keys().then(k=>Promise.all(k.filter(x=>x!==C).map(x=>caches.delete(x)))));self.clients.claim();});
self.addEventListener("fetch",e=>{
  const u=new URL(e.request.url);
  if(e.request.method!=="GET"||u.hostname.endsWith("supabase.co")) return;
  const fresh=e.request.mode==="navigate"||/\.(html|js|webmanifest)$/.test(u.pathname)||u.pathname.endsWith("/");
  e.respondWith(fetch(e.request,fresh?{cache:"no-cache"}:{}).then(r=>{const cp=r.clone();caches.open(C).then(c=>c.put(e.request,cp));return r;}).catch(()=>caches.match(e.request).then(r=>r||caches.match("index.html"))));
});

self.addEventListener("push",e=>{
  let d={}; try{d=e.data?e.data.json():{}}catch(x){d={body:e.data&&e.data.text()}}
  e.waitUntil(self.registration.showNotification(d.title||"littles noor",{body:d.body||"",icon:"icon-192.png",badge:"icon-192.png",data:{url:d.url||"./"}}));
});
self.addEventListener("notificationclick",e=>{
  e.notification.close(); const url=new URL((e.notification.data&&e.notification.data.url)||"./",self.registration.scope).href;
  e.waitUntil(clients.matchAll({type:"window",includeUncontrolled:true}).then(cs=>{for(const c of cs){if(c.url.startsWith(self.registration.scope)){c.focus();return c.navigate?c.navigate(url).catch(()=>{}):null;}}return clients.openWindow(url);}));
});

// ==UserScript==
// @name         Naumen → Речевой скрипт: передать клиента (ШАБЛОН)
// @namespace    local.naumen.script.bridge
// @version      0.1.7
// @description  Плавающая кнопка в Naumen Webphone: вытаскивает ссылку Bitrix и строку клиента,
//               передаёт данные в локальный index.html речевого скрипта.
//               ВАЖНО: в шаблоне НЕТ зашитого Bitrix-токена. Введите свой вебхук через localStorage
//               (см. инструкцию внизу), иначе подтяжка имени из Bitrix работать не будет.
// @match        https://tetrika.nau.team:8443/webphone*
// @match        https://tetrika.nau.team:8443/*
// @grant        GM_xmlhttpRequest
// @run-at       document-idle
// ==/UserScript==

(function(){
  'use strict';

  if(window.top !== window.self) return;

  // Если запускаешь index.html через локальный сервер — оставь так.
  const SCRIPT_URL = localStorage.getItem('rm_bridge_script_url') || 'http://localhost:8000/index.html';

  const BITRIX_RE = /https?:\/\/bitrix\.tetrika\.school\/crm\/(contact|deal|lead)\/details\/\d+\/?/i;

  // БЕЗОПАСНО: нет зашитого токена. Вебхук задаётся вручную через localStorage:
  //   localStorage.setItem('rm_bitrix_webhook', 'https://bitrix.../rest/ID/TOKEN/')
  // Если не задан — подтяжка имени из Bitrix просто пропускается (без ошибок).
  function getBitrixWebhook() {
    return localStorage.getItem('rm_bitrix_webhook') || '';
  }

  function b64UrlEncodeUtf8(obj){
    const json = JSON.stringify(obj);
    const bytes = new TextEncoder().encode(json);
    let bin = '';
    bytes.forEach(b => { bin += String.fromCharCode(b); });
    return btoa(bin).replace(/\+/g,'-').replace(/\//g,'_').replace(/=+$/,'');
  }

  function norm(s){ return String(s||'').replace(/\s+/g,' ').trim(); }

  function getDocs(win = window, out = []){
    try{
      if(win.document && !out.includes(win.document)) out.push(win.document);
      const frames = win.document ? Array.from(win.document.querySelectorAll('iframe, frame')) : [];
      frames.forEach(fr => {
        try{
          if(fr.contentWindow) getDocs(fr.contentWindow, out);
        }catch(e){}
      });
    }catch(e){}
    return out;
  }

  function findBitrixUrl(){
    for(const doc of getDocs()){
      for(const a of Array.from(doc.querySelectorAll('a[href]'))){
        const href = a.href || a.getAttribute('href') || '';
        const m = href.match(BITRIX_RE);
        if(m) return m[0];
      }
      const html = doc.documentElement?.innerHTML || '';
      const m = html.match(BITRIX_RE);
      if(m) return m[0];
    }
    return '';
  }

  function scoreClientLine(line){
    line = norm(line);
    if(line.length < 8 || line.length > 220) return 0;
    if(/^\d{1,2}:\d{2}:\d{2}$/.test(line)) return 0;
    let score = 0;
    if(/(^|\s)Р\s+[А-ЯЁA-Z][а-яёa-z-]+/.test(line)) score += 4;
    if(/(^|\s)У\s+[А-ЯЁA-Z][а-яёa-z-]+/.test(line)) score += 4;
    if(/\d+\s*(?:кл|класс)?\b/i.test(line)) score += 2;
    if(/битрикс|bitrix|телефон|звонок|crm/i.test(line)) score -= 2;
    return score;
  }

  function findClientRawInDoc(doc){
    const candidates = [];
    const selectors = [
      '[class*=client]', '[class*=customer]', '[class*=contact]', '[class*=crm]',
      '[data-testid]', '[title]', 'span', 'div', 'td'
    ];
    doc.querySelectorAll(selectors.join(',')).forEach(el=>{
      const txt = norm(el.innerText || el.textContent || el.getAttribute('title') || '');
      const sc = scoreClientLine(txt);
      if(sc>=4) candidates.push({txt, sc});
    });
    const bodyText = norm(doc.body?.innerText || '');
    const m = bodyText.match(new RegExp('(?:^|\\s)Р\\s+[А-ЯЁA-Z][А-ЯЁA-Zа-яёa-z-]*(?:\\s+[^\\n\\r]{0,80})?\\s+У\\s+[А-ЯЁA-Z][А-ЯЁA-Zа-яёa-z-]*(?:\\s+\\d{1,2}\\s*(?:кл|класс)?)?(?:[,;]\\s*У\\s+[А-ЯЁA-Z][А-ЯЁA-Zа-яёa-z-]*(?:\\s+\\d{1,2}\\s*(?:кл|класс)?)?)*', 'i'));
    if(m){
      const txt = norm(m[0]);
      const sc = scoreClientLine(txt) + 1;
      if(sc>=4) candidates.push({txt, sc});
    }
    candidates.sort((a,b)=>b.sc-a.sc || a.txt.length-b.txt.length);
    return candidates[0]?.txt || '';
  }

  function findClientRaw(){
    const docs = getDocs();
    let bestTxt = '';
    let maxScore = -1;
    for(const doc of docs){
      const txt = findClientRawInDoc(doc);
      if(txt){
        const sc = scoreClientLine(txt);
        if(sc > maxScore){ maxScore = sc; bestTxt = txt; }
      }
    }
    return bestTxt;
  }

  async function fetchClientNameFromBitrix(url){
    // Без заданного вебхука (localStorage.rm_bitrix_webhook) ничего не запрашиваем.
    const webhook = getBitrixWebhook();
    if(!webhook) return '';

    if(!url) return '';
    const match = url.match(BITRIX_RE);
    if(!match) return '';
    const type = match[1];
    const id = url.split('/details/')[1]?.split('/')[0];
    if(!id) return '';

    const deepSearchPattern = (obj, pattern) => {
      if(!obj) return null;
      if(typeof obj === 'string'){ if(pattern.test(obj)) return norm(obj); }
      else if(Array.isArray(obj)){ for(const item of obj){ const f = deepSearchPattern(item, pattern); if(f) return f; } }
      else if(typeof obj === 'object'){ for(const key in obj){ const f = deepSearchPattern(obj[key], pattern); if(f) return f; } }
      return null;
    };

    const clientPattern = new RegExp('(?:^|\\s)Р\\s+[А-ЯЁA-Z][А-ЯЁA-Zа-яёa-z-]*(?:\\s+[^\\n\\r]{0,80})?\\s+У\\s+[А-ЯЁA-Z][А-ЯЁA-Zа-яёa-z-]*(?:\\s+\\d{1,2}\\s*(?:кл|класс)?)?(?:[,;]\\s*У\\s+[А-ЯЁA-Z][А-ЯЁA-Zа-яёa-z-]*(?:\\s+\\d{1,2}\\s*(?:кл|класс)?)?)*', 'i');

    try {
      const method = 'crm.' + type + '.get';
      const apiUrl = `${webhook}${method}?id=${id}`;
      const response = await new Promise((resolve, reject) => {
        GM_xmlhttpRequest({ method:'GET', url:apiUrl, onload:(res)=>resolve(res.responseText), onerror:(err)=>reject(err) });
      });
      const data = JSON.parse(response);
      if(data.result){
        const found = deepSearchPattern(data.result, clientPattern);
        if(found) return found;
      }
    } catch(e) { console.warn('[BitrixAPI] Error during primary fetch:', e); }

    try {
      let contactId = null;
      const typeUrl = `${webhook}crm.${type}.get?id=${id}`;
      const typeRes = JSON.parse(await new Promise(res => GM_xmlhttpRequest({method:'GET', url:typeUrl, onload: r=>res(r.responseText)})));
      if(typeRes.result){ contactId = typeRes.result.CONTACT_ID || typeRes.result.contact_id; }
      if(contactId){
        const contactUrl = `${webhook}crm.contact.get?id=${contactId}`;
        const contactResText = await new Promise(res => GM_xmlhttpRequest({method:'GET', url:contactUrl, onload: r=>res(r.responseText)}));
        const contactData = JSON.parse(contactResText);
        if(contactData.result){
          const found = deepSearchPattern(contactData.result, clientPattern);
          if(found) return found;
        }
      }
    } catch(e) { console.warn('[BitrixAPI] Error during linked contact fetch:', e); }

    console.log('[BitrixAPI] API failed, trying scraping (may fail for modals)...');
    return new Promise((resolve)=>{
      GM_xmlhttpRequest({ method:'GET', url:url, onload:function(response){
        try {
          const parser = new DOMParser();
          const doc = parser.parseFromString(response.responseText, 'text/html');
          resolve(findClientRawInDoc(doc));
        } catch(e) { resolve(''); }
      }, onerror:()=>resolve('') });
    });
  }

  function parseNaumenClientLine(raw){
    raw = norm(raw);
    const out = { raw, parentName:'', childName:'', class:'', children:[] };
    const parent = raw.match(/(?:^|\s)Р\s+([А-ЯЁA-Z][А-ЯЁA-Zа-яёa-z-]*)/);
    if(parent) out.parentName = parent[1];
    const childRe = /(?:^|[\s,;])У\s+([А-ЯЁA-Z][А-ЯЁA-Zа-яёa-z-]*)(?:\s+(\d{1,2})\s*(?:кл|класс)?)?/gi;
    let m;
    while((m = childRe.exec(raw))){ out.children.push({ name:m[1], class:m[2]||'' }); }
    if(out.children.length){
      const gradeNum = c => { const n = parseInt(String(c.class||'').replace(/\D/g,''), 10); return Number.isFinite(n) ? n : 99; };
      const target = out.children.slice().sort((a,b)=> gradeNum(a) - gradeNum(b))[0];
      out.targetChild = target; out.childName = target.name; out.class = target.class || '';
    }
    return out;
  }

  function findPhoneNumber(){
    for(const doc of getDocs()){
      const labels = Array.from(doc.querySelectorAll('label'));
      for(const label of labels){
        if(norm(label.innerText).includes('Номер')){
          if(label.htmlFor){ const el = doc.getElementById(label.htmlFor); if(el && el.value !== undefined) return norm(el.value); }
          let next = label.nextElementSibling;
          while(next && next.tagName !== 'INPUT' && next.tagName !== 'SELECT' && next.tagName !== 'TEXTAREA') next = next.nextElementSibling;
          if(next && next.value !== undefined) return norm(next.value);
          const parent = label.parentElement;
          if(parent){ const inp = parent.querySelector('input, select, textarea'); if(inp && inp !== label && inp.value !== undefined) return norm(inp.value); }
        }
      }
    }
    return '';
  }

  async function collectPayload(){
    const bitrixUrl = findBitrixUrl();
    let raw = findClientRaw();
    if(!raw && bitrixUrl){ raw = await fetchClientNameFromBitrix(bitrixUrl); }
    const parsed = parseNaumenClientLine(raw);
    return { source:'naumen-webphone-userscript', ts:new Date().toISOString(), pageUrl:location.href, bitrixUrl, phone_number:findPhoneNumber(), ...parsed };
  }

  function payloadUseful(payload){
    return !!(payload.bitrixUrl || payload.parentName || payload.childName || payload.class || payload.phone_number || (payload.children && payload.children.length));
  }

  function openScriptWithPayload(payload){
    const encoded = b64UrlEncodeUtf8(payload);
    const url = SCRIPT_URL.replace(/#.*$/,'') + '#naumen=' + encodeURIComponent(encoded);
    const w = window.open(url, 'rm_script');
    if(w) setTimeout(()=>{ try{ w.focus(); }catch(e){} }, 50);
  }

  function showDebug(payload){
    const ok = payloadUseful(payload);
    alert((ok ? 'Naumen → скрипт: данные найдены' : 'Naumen → скрипт: данные клиента не найдены')+
      '\n\nBitrix: '+(payload.bitrixUrl||'не найдено')+
      '\nТелефон: '+(payload.phone_number||'не найден')+
      '\nСтрока: '+(payload.raw||'не найдена')+
      '\nРодитель: '+(payload.parentName||'-')+
      '\nУченик: '+(payload.childName||'-')+
      '\nКласс: '+(payload.class||'-')+
      (payload.children?.length>1 ? '\nЦелевой ученик: '+(payload.childName||'-')+' '+(payload.class||'-')+'кл' : '')+
      (payload.children?.length>1 ? '\nВсе ученики: '+payload.children.map(c=>c.name+' '+(c.class||'')+'кл').join(', ') : '')+
      (!ok ? '\n\nЭто нормально вне открытого звонка/мини-CRM. Если звонок открыт — нужна донастройка селекторов.' : '')
    );
  }

  function ensureButton(){
    if(document.getElementById('rmBridgeBtn')) return;
    const btn = document.createElement('button');
    btn.id = 'rmBridgeBtn'; btn.type = 'button';
    btn.textContent = '▶ Передать в скрипт';
    btn.title = 'Перетащи за кнопку, чтобы переместить. Shift+клик — диагностика.';
    const pos = JSON.parse(localStorage.getItem('rm_bridge_btn_pos') || '{}');
    Object.assign(btn.style, {
      position:'fixed', zIndex:2147483647,
      left:(pos.left || 18)+'px', top:(pos.top || 90)+'px',
      padding:'10px 14px', border:'0', borderRadius:'10px',
      background:'#4f8cff', color:'#fff', font:'600 13px Arial,sans-serif',
      boxShadow:'0 6px 20px rgba(0,0,0,.35)', cursor:'move'
    });

    let dragging=false, moved=false, dx=0, dy=0, startX=0, startY=0;
    btn.addEventListener('mousedown', e=>{
      dragging=true; moved=false;
      startX = e.clientX; startY = e.clientY;
      dx=e.clientX-btn.offsetLeft; dy=e.clientY-btn.offsetTop; e.preventDefault();
    });
    window.addEventListener('mousemove', e=>{
      if(!dragging) return;
      const dist = Math.hypot(e.clientX - startX, e.clientY - startY);
      if(dist > 5) moved=true;
      const left=Math.max(0, Math.min(window.innerWidth-btn.offsetWidth, e.clientX-dx));
      const top=Math.max(0, Math.min(window.innerHeight-btn.offsetHeight, e.clientY-dy));
      btn.style.left=left+'px'; btn.style.top=top+'px';
    });
    window.addEventListener('mouseup', ()=>{
      if(!dragging) return;
      dragging=false;
      localStorage.setItem('rm_bridge_btn_pos', JSON.stringify({left:parseInt(btn.style.left), top:parseInt(btn.style.top)}));
    });
    btn.addEventListener('click', async e=>{
      if(moved){ moved=false; return; }
      const payload = await collectPayload();
      if(e.shiftKey){ showDebug(payload); return; }
      openScriptWithPayload(payload);
    });
    document.body.appendChild(btn);
  }

  ensureButton();
  new MutationObserver(()=>ensureButton()).observe(document.documentElement, {childList:true, subtree:true});
})();

/* ============================================================
   ИНСТРУКЦИЯ (для себя, можно удалить):
   Чтобы включить подтяжку имени клиента из Bitrix, задайте свой вебхук:
   1) Откройте консоль браузера на странице tetrika.nau.team.
   2) Вставьте и выполните:
        localStorage.setItem('rm_bitrix_webhook', 'https://bitrix.tetrika.school/rest/ВАШ_ID/ВАШ_ТОКЕН/');
      Замените ВАШ_ID / ВАШ_ТОКЕН на данные вашего Bitrix-вебхука (Битрикс24 → Разработчикам → Другие → REST API → добавить вебхук, права: crm.*).
   3) Скрипт подхватит его автоматически (localStorage имеет приоритет).
   Если вебхук не задан — скрипт работает, но имя из Bitrix не добирает (без ошибок).
   НЕ вшивайте токен в код, если планируете публиковать скрипт.
============================================================ */

/* Nova Phone - NUI */
const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'nova_phone';
const DEV = typeof GetParentResourceName !== 'function'; // opened in a normal browser -> preview with mock data

const $ = (s, r = document) => r.querySelector(s);
const $$ = (s, r = document) => [...r.querySelectorAll(s)];
const h = s => String(s ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const money = n => '$' + Math.round(Number(n) || 0).toLocaleString('en-US');
const initials = n => String(n || '?').split(' ').map(w => w[0]).join('').slice(0, 2).toUpperCase();
const ago = ts => {
  if (!ts) return 'now';
  const d = Math.floor(Date.now() / 1000 - ts);
  if (d < 60) return 'now';
  if (d < 3600) return Math.floor(d / 60) + 'm';
  if (d < 86400) return Math.floor(d / 3600) + 'h';
  return Math.floor(d / 86400) + 'd';
};

const S = { profile: null, contacts: [], stack: [], current: null, call: null, callTimer: null, badges: {} };

/* ---------- transport ---------- */
async function post(endpoint, data = {}) {
  if (DEV) return Mock.handle(endpoint, data);
  try {
    const r = await fetch(`https://${RES}/${endpoint}`, { method: 'POST', headers: { 'Content-Type': 'application/json; charset=UTF-8' }, body: JSON.stringify(data) });
    return await r.json();
  } catch (e) { return { ok: false, msg: 'Connection error' }; }
}
const api = (action, payload = {}) => post('request', { action, payload });

/* ---------- apps registry ---------- */
const APPS = [
  { id: 'phone',      name: 'Phone',     icon: 'fa-phone',            color: 'linear-gradient(135deg,#4cd964,#2fb24c)' },
  { id: 'messages',   name: 'Messages',  icon: 'fa-comment',          color: 'linear-gradient(135deg,#5ef08a,#28c75a)' },
  { id: 'contacts',   name: 'Contacts',  icon: 'fa-address-book',     color: 'linear-gradient(135deg,#a2a6b4,#6f7385)' },
  { id: 'settings',   name: 'Settings',  icon: 'fa-gear',             color: 'linear-gradient(135deg,#8e93a3,#4b4f5c)' },
  { id: 'bank',       name: 'Fleeca',    icon: 'fa-building-columns', color: 'linear-gradient(135deg,#2bd47d,#0e8f4e)' },
  { id: 'chirp',      name: 'Chirp',     icon: 'fa-feather',          color: 'linear-gradient(135deg,#3db4ff,#1374e0)' },
  { id: 'ads',        name: 'Yellow Pages', icon: 'fa-bullhorn',      color: 'linear-gradient(135deg,#ffd43b,#f59f00)' },
  { id: 'mail',       name: 'Mail',      icon: 'fa-envelope',         color: 'linear-gradient(135deg,#55a8ff,#2563eb)' },
  { id: 'notes',      name: 'Notes',     icon: 'fa-note-sticky',      color: 'linear-gradient(135deg,#ffe066,#fcc419)' },
  { id: 'calculator', name: 'Calculator',icon: 'fa-calculator',       color: 'linear-gradient(135deg,#ff9f43,#e8590c)' },
  { id: 'garage',     name: 'Garage',    icon: 'fa-car',              color: 'linear-gradient(135deg,#ff6b6b,#c92a2a)' },
  { id: 'services',   name: 'Services',  icon: 'fa-tower-broadcast',  color: 'linear-gradient(135deg,#845ef7,#5f3dc4)' },
];
const DOCK = ['phone', 'messages', 'contacts', 'settings'];
const WALLPAPERS = ['aurora', 'sunset', 'ocean', 'midnight', 'forest', 'candy'];

/* ---------- helpers ---------- */
const contactName = num => (S.contacts.find(c => c.number === num) || {}).name;
const display = num => contactName(num) || num;

function toast(title, text, icon = 'fa-bell', color = '#4f7cff', onClick) {
  if (S.profile?.settings?.muted && !onClick) return;
  const el = document.createElement('div');
  el.className = 'toast';
  el.innerHTML = `<div class="ti" style="background:${color}"><i class="fa-solid ${icon}"></i></div><div><b>${h(title)}</b>${h(text)}</div>`;
  if (onClick) el.onclick = () => { onClick(); el.remove(); };
  $('#toasts').appendChild(el);
  setTimeout(() => { el.classList.add('out'); setTimeout(() => el.remove(), 300); }, 3500);
}
const fail = r => toast('Error', r?.msg || 'Something went wrong', 'fa-triangle-exclamation', '#ff3b30');

function setAction(icon, fn) {
  const a = $('#appAction');
  a.innerHTML = icon ? `<button class="icon-btn"><i class="fa-solid ${icon}"></i></button>` : '';
  if (icon) a.firstChild.onclick = fn;
}

function setBadge(id, n) {
  S.badges[id] = n;
  $$(`[data-app="${id}"] .badge`).forEach(b => b.remove());
  if (n > 0) $$(`[data-app="${id}"]`).forEach(el => el.insertAdjacentHTML('beforeend', `<span class="badge">${n > 99 ? '99+' : n}</span>`));
}

/* ---------- home & navigation ---------- */
function iconHTML(a) {
  return `<div class="app-icon" data-app="${a.id}"><div class="ico" style="background:${a.color}"><i class="fa-solid ${a.icon}"></i></div><span>${h(a.name)}</span></div>`;
}
function renderHome() {
  $('#appGrid').innerHTML = APPS.filter(a => !DOCK.includes(a.id)).map(iconHTML).join('');
  $('#dock').innerHTML = DOCK.map(id => iconHTML(APPS.find(a => a.id === id))).join('');
  $$('.app-icon').forEach(el => el.onclick = () => openApp(el.dataset.app));
  Object.entries(S.badges).forEach(([k, v]) => setBadge(k, v));
}

function goHome() {
  S.stack = []; S.current = null;
  $('#app').classList.add('hidden');
  $('#home').classList.remove('hidden');
}

function openApp(id, params = {}, push = true) {
  const app = APPS.find(a => a.id === id) || { name: params.title || '' };
  if (push) S.stack.push({ id, params });
  S.current = { id, params };
  $('#home').classList.add('hidden');
  const appEl = $('#app');
  appEl.classList.remove('hidden');
  appEl.style.animation = 'none'; void appEl.offsetWidth; appEl.style.animation = '';
  $('#appTitle').textContent = params.title || app.name;
  setAction(null);
  const body = $('#appBody');
  body.className = 'app-body';
  body.innerHTML = '';
  (Views[id] || (() => body.innerHTML = '<div class="empty">Coming soon</div>'))(body, params);
}

function back() {
  S.stack.pop();
  const prev = S.stack[S.stack.length - 1];
  if (!prev) return goHome();
  openApp(prev.id, prev.params, false);
}

/* ---------- views ---------- */
const Views = {};

/* Phone / dialer */
Views.phone = (body, params) => {
  const tab = params.tab || 'keypad';
  body.innerHTML = `<div class="tabs"><button data-t="keypad">Keypad</button><button data-t="recents">Recents</button></div><div id="ph"></div>`;
  $$('.tabs button', body).forEach(b => { b.classList.toggle('active', b.dataset.t === tab); b.onclick = () => { S.current.params.tab = b.dataset.t; S.stack[S.stack.length - 1].params.tab = b.dataset.t; Views.phone(body, { ...params, tab: b.dataset.t }); }; });
  const ph = $('#ph', body);
  if (tab === 'keypad') {
    let num = params.number || '';
    const keys = [['1', ''], ['2', 'ABC'], ['3', 'DEF'], ['4', 'GHI'], ['5', 'JKL'], ['6', 'MNO'], ['7', 'PQRS'], ['8', 'TUV'], ['9', 'WXYZ'], ['*', ''], ['0', '+'], ['#', '']];
    ph.innerHTML = `<div class="dial-display" id="dd"></div><div class="dial-name" id="dn"></div>
      <div class="keypad">${keys.map(([k, l]) => `<button class="key" data-k="${k}">${k}<small>${l}</small></button>`).join('')}</div>
      <div class="dial-actions"><span></span><button class="call-btn" id="dial"><i class="fa-solid fa-phone"></i></button><button class="key" id="del" style="background:none"><i class="fa-solid fa-delete-left" style="font-size:22px"></i></button></div>`;
    const upd = () => { $('#dd', ph).textContent = num; $('#dn', ph).textContent = contactName(num) || ''; };
    $$('.key[data-k]', ph).forEach(k => k.onclick = () => { if (num.length < 15) num += k.dataset.k; upd(); });
    $('#del', ph).onclick = () => { num = num.slice(0, -1); upd(); };
    $('#dial', ph).onclick = () => num && startCall(num);
    upd();
  } else {
    ph.innerHTML = '<div class="empty"><i class="fa-solid fa-spinner fa-spin"></i></div>';
    api('callHistory').then(r => {
      if (!r.ok || !r.list.length) return ph.innerHTML = '<div class="empty"><i class="fa-solid fa-clock-rotate-left"></i>No recent calls</div>';
      ph.innerHTML = `<div class="list">${r.list.map(c => {
        const missed = c.status !== 'answered';
        const icon = c.outgoing ? 'fa-arrow-up-right' : 'fa-arrow-down-left';
        return `<div class="row" data-n="${h(c.number)}"><div class="avatar">${h(initials(display(c.number)))}</div>
          <div class="grow"><div class="title" style="${missed && !c.outgoing ? 'color:var(--red)' : ''}">${h(display(c.number))}</div>
          <div class="sub"><i class="fa-solid ${icon}"></i> ${c.outgoing ? 'Outgoing' : 'Incoming'} · ${h(c.status)}</div></div>
          <div class="meta">${ago(c.ts)}</div></div>`;
      }).join('')}</div>`;
      $$('.row', ph).forEach(r => r.onclick = () => startCall(r.dataset.n));
    });
  }
};

/* Contacts */
Views.contacts = async (body) => {
  setAction('fa-plus', () => openApp('contactForm', { title: 'New Contact' }));
  const r = await api('contactsGet');
  if (r.ok) S.contacts = r.list;
  const draw = (q = '') => {
    const list = S.contacts.filter(c => (c.name + c.number).toLowerCase().includes(q.toLowerCase()));
    $('#cl', body).innerHTML = list.length ? `<div class="list">${list.map(c => `<div class="row" data-id="${c.id}"><div class="avatar">${h(initials(c.name))}</div><div class="grow"><div class="title">${h(c.name)}</div><div class="sub">${h(c.number)}</div></div><i class="fa-solid fa-chevron-right" style="color:var(--muted);font-size:12px"></i></div>`).join('')}</div>`
      : '<div class="empty"><i class="fa-solid fa-address-book"></i>No contacts yet</div>';
    $$('#cl .row', body).forEach(row => row.onclick = () => openApp('contactView', { title: 'Contact', contact: S.contacts.find(c => c.id == row.dataset.id) }));
  };
  body.innerHTML = `<div class="search"><i class="fa-solid fa-magnifying-glass"></i><input class="field" id="q" placeholder="Search"></div>
    <div class="card" style="display:flex;gap:12px;align-items:center"><div class="avatar">${h(initials(S.profile.name))}</div><div><b>${h(S.profile.name)}</b><div style="color:var(--muted);font-size:12px">My number · ${h(S.profile.number)}</div></div></div><div id="cl"></div>`;
  $('#q', body).oninput = e => draw(e.target.value);
  draw();
};

Views.contactForm = (body, p) => {
  body.innerHTML = `<label class="label">Name</label><input class="field" id="n" maxlength="50" value="${h(p.name || '')}">
    <label class="label">Phone number</label><input class="field" id="num" maxlength="20" value="${h(p.number || '')}">
    <button class="btn" id="save">Save contact</button>`;
  $('#save', body).onclick = async () => {
    const r = await api('contactsAdd', { name: $('#n', body).value, number: $('#num', body).value });
    if (!r.ok) return fail(r);
    toast('Contacts', 'Contact saved', 'fa-check', '#34c759');
    back();
  };
};

Views.contactView = (body, { contact: c }) => {
  body.innerHTML = `<div style="text-align:center;margin:10px 0 20px"><div class="avatar" style="width:84px;height:84px;font-size:30px;margin:0 auto 12px">${h(initials(c.name))}</div>
    <div style="font-size:22px;font-weight:700">${h(c.name)}</div><div style="color:var(--muted)">${h(c.number)}</div></div>
    <div class="btn-row"><button class="btn" id="call"><i class="fa-solid fa-phone"></i> Call</button><button class="btn ghost" id="msg"><i class="fa-solid fa-comment"></i> Message</button></div>
    <button class="btn red" id="del" style="margin-top:20px">Delete contact</button>`;
  $('#call', body).onclick = () => startCall(c.number);
  $('#msg', body).onclick = () => openApp('chat', { title: c.name, number: c.number });
  $('#del', body).onclick = async () => { await api('contactsDelete', { id: c.id }); S.contacts = S.contacts.filter(x => x.id !== c.id); back(); };
};

/* Messages */
Views.messages = async (body) => {
  setAction('fa-pen-to-square', () => openApp('newMessage', { title: 'New Message' }));
  body.innerHTML = '<div class="empty"><i class="fa-solid fa-spinner fa-spin"></i></div>';
  const r = await api('messagesThreads');
  if (!r.ok || !r.list.length) return body.innerHTML = '<div class="empty"><i class="fa-solid fa-comments"></i>No conversations yet</div>';
  setBadge('messages', r.list.reduce((a, t) => a + (t.unread || 0), 0));
  body.innerHTML = `<div class="list">${r.list.map(t => `<div class="row" data-n="${h(t.number)}">
    <div class="avatar">${h(initials(display(t.number)))}</div>
    <div class="grow"><div class="title">${h(display(t.number))}</div><div class="sub">${h(t.last)}</div></div>
    <div style="display:flex;flex-direction:column;align-items:flex-end;gap:6px"><span class="meta">${ago(t.ts)}</span>${t.unread ? '<span class="dot"></span>' : ''}</div></div>`).join('')}</div>`;
  $$('.row', body).forEach(row => row.onclick = () => openApp('chat', { title: display(row.dataset.n), number: row.dataset.n }));
};

Views.newMessage = (body) => {
  body.innerHTML = `<label class="label">To</label><input class="field" id="to" list="cdl" placeholder="Phone number">
    <datalist id="cdl">${S.contacts.map(c => `<option value="${h(c.number)}">${h(c.name)}</option>`).join('')}</datalist>
    <button class="btn" id="go">Start conversation</button>`;
  $('#go', body).onclick = () => { const n = $('#to', body).value.trim(); if (n) { S.stack.pop(); openApp('chat', { title: display(n), number: n }); } };
};

Views.chat = async (body, { number }) => {
  setAction('fa-phone', () => startCall(number));
  body.classList.add('fill');
  body.innerHTML = `<div class="chat"><div class="bubbles" id="bb"></div>
    <div class="composer"><input class="field" id="txt" maxlength="500" placeholder="Message"><button class="send" id="snd"><i class="fa-solid fa-arrow-up"></i></button></div></div>`;
  const bb = $('#bb', body);
  const add = m => { bb.insertAdjacentHTML('beforeend', `<div class="bubble ${m.mine ? 'mine' : 'theirs'}">${h(m.text)}<span class="t">${ago(m.ts)}</span></div>`); bb.scrollTop = bb.scrollHeight; };
  const r = await api('messagesGet', { number });
  if (r.ok) r.list.forEach(add);
  const send = async () => {
    const inp = $('#txt', body); const text = inp.value.trim();
    if (!text) return;
    inp.value = '';
    const res = await api('messagesSend', { number, text });
    if (!res.ok) return fail(res);
    add({ mine: true, text, ts: res.ts });
  };
  $('#snd', body).onclick = send;
  $('#txt', body).onkeydown = e => { if (e.key === 'Enter') send(); };
  $('#txt', body).focus();
  S.chatAppend = (from, text, ts) => { if (from === number) add({ mine: false, text, ts }); return from === number; };
};

/* Bank */
Views.bank = async (body) => {
  body.innerHTML = '<div class="empty"><i class="fa-solid fa-spinner fa-spin"></i></div>';
  const r = await api('bankGet');
  if (!r.ok) return fail(r);
  body.innerHTML = `<div class="balance"><small>Checking account</small><div class="amt">${money(r.bank)}</div>
      <div class="split"><span>${h(S.profile.name)}</span><span>Cash: ${money(r.cash)}</span></div></div>
    <div class="card"><b style="display:block;margin-bottom:10px">Send money</b>
      <input class="field" id="to" list="bdl" placeholder="Recipient phone number">
      <datalist id="bdl">${S.contacts.map(c => `<option value="${h(c.number)}">${h(c.name)}</option>`).join('')}</datalist>
      <input class="field" id="amt" type="number" min="1" placeholder="Amount">
      <button class="btn" id="send">Transfer</button></div>
    <b style="display:block;margin:14px 2px 8px">Recent activity</b>
    ${r.log.length ? `<div class="list">${r.log.map(l => `<div class="row" style="cursor:default"><div class="grow"><div class="title">${h(l.label)}</div><div class="sub">${ago(l.ts)} ago</div></div><span class="${l.amount < 0 ? 'neg' : 'pos'}">${l.amount < 0 ? '-' : '+'}${money(Math.abs(l.amount))}</span></div>`).join('')}</div>` : '<div class="empty">No transactions yet</div>'}`;
  $('#send', body).onclick = async e => {
    e.target.disabled = true;
    const res = await api('bankTransfer', { number: $('#to', body).value.trim(), amount: $('#amt', body).value });
    e.target.disabled = false;
    if (!res.ok) return fail(res);
    toast('Fleeca', 'Transfer complete', 'fa-check', '#34c759');
    Views.bank(body);
  };
};

/* Chirp */
Views.chirp = async (body) => {
  const max = S.profile.chirpMax || 280;
  body.innerHTML = `<div class="card"><textarea class="field" id="ct" rows="3" maxlength="${max}" placeholder="What's happening?"></textarea>
    <div class="counter" id="cc">0/${max}</div><button class="btn" id="cp">Chirp</button></div><div id="feed"><div class="empty"><i class="fa-solid fa-spinner fa-spin"></i></div></div>`;
  $('#ct', body).oninput = e => $('#cc', body).textContent = `${e.target.value.length}/${max}`;
  $('#cp', body).onclick = async () => {
    const res = await api('chirpPost', { text: $('#ct', body).value });
    if (!res.ok) return fail(res);
    $('#ct', body).value = ''; load();
  };
  const load = async () => {
    const r = await api('chirpGet');
    const feed = $('#feed', body);
    if (!feed) return;
    if (!r.ok || !r.list.length) return feed.innerHTML = '<div class="empty"><i class="fa-solid fa-feather"></i>Be the first to chirp</div>';
    feed.innerHTML = r.list.map(c => `<div class="chirp" data-id="${c.id}"><div class="chirp-head"><div class="avatar">${h(initials(c.author))}</div>
      <div><b>${h(c.author)}</b> <span>${h(c.handle)} · ${ago(c.ts)}</span></div></div><p>${h(c.content)}</p>
      <div class="chirp-foot"><button class="like ${c.liked ? 'liked' : ''}"><i class="fa-${c.liked ? 'solid' : 'regular'} fa-heart"></i> <span>${c.likes}</span></button>
      ${c.mine ? '<button class="del"><i class="fa-regular fa-trash-can"></i></button>' : ''}</div></div>`).join('');
    $$('.chirp', feed).forEach(el => {
      const id = el.dataset.id;
      $('.like', el).onclick = async () => {
        const res = await api('chirpLike', { id });
        if (!res.ok) return;
        const b = $('.like', el);
        b.classList.toggle('liked', !!res.liked);
        b.innerHTML = `<i class="fa-${res.liked ? 'solid' : 'regular'} fa-heart"></i> <span>${res.likes}</span>`;
      };
      const d = $('.del', el); if (d) d.onclick = async () => { await api('chirpDelete', { id }); el.remove(); };
    });
  };
  S.chirpReload = load;
  load();
};

/* Yellow Pages */
Views.ads = async (body) => {
  setAction('fa-plus', () => openApp('adForm', { title: 'New Ad' }));
  body.innerHTML = '<div class="empty"><i class="fa-solid fa-spinner fa-spin"></i></div>';
  const r = await api('adsGet');
  if (!r.ok || !r.list.length) return body.innerHTML = '<div class="empty"><i class="fa-solid fa-bullhorn"></i>No ads right now</div>';
  body.innerHTML = r.list.map(a => `<div class="card" data-id="${a.id}">
    <div style="display:flex;justify-content:space-between;gap:8px"><b>${h(a.title)}</b>${a.price != null ? `<span class="pill" style="background:#ffd43b;color:#000">${money(a.price)}</span>` : ''}</div>
    <p style="font-size:13px;margin:6px 0 10px;color:#cfd2da;white-space:pre-wrap">${h(a.body)}</p>
    <div style="display:flex;justify-content:space-between;align-items:center;font-size:12px;color:var(--muted)"><span>${h(a.author)} · ${ago(a.ts)}</span>
      <span style="display:flex;gap:4px">${a.mine ? '<button class="icon-btn del" style="color:var(--red)"><i class="fa-regular fa-trash-can"></i></button>'
        : `<button class="icon-btn call" data-n="${h(a.number)}"><i class="fa-solid fa-phone"></i></button><button class="icon-btn msg" data-n="${h(a.number)}"><i class="fa-solid fa-comment"></i></button>`}</span></div></div>`).join('');
  $$('.call', body).forEach(b => b.onclick = () => startCall(b.dataset.n));
  $$('.msg', body).forEach(b => b.onclick = () => openApp('chat', { title: display(b.dataset.n), number: b.dataset.n }));
  $$('.del', body).forEach(b => b.onclick = async () => { await api('adsDelete', { id: b.closest('.card').dataset.id }); Views.ads(body); });
};

Views.adForm = (body) => {
  const cost = S.profile.adCost || 0;
  body.innerHTML = `<label class="label">Title</label><input class="field" id="t" maxlength="80">
    <label class="label">Description</label><textarea class="field" id="b" rows="5" maxlength="500"></textarea>
    <label class="label">Price (optional)</label><input class="field" id="p" type="number" min="0">
    <button class="btn" id="post">Post ad${cost ? ` · ${money(cost)}` : ''}</button>`;
  $('#post', body).onclick = async () => {
    const r = await api('adsPost', { title: $('#t', body).value, body: $('#b', body).value, price: $('#p', body).value || null });
    if (!r.ok) return fail(r);
    toast('Yellow Pages', 'Your ad is live', 'fa-check', '#34c759');
    back();
  };
};

/* Mail */
Views.mail = async (body) => {
  body.innerHTML = '<div class="empty"><i class="fa-solid fa-spinner fa-spin"></i></div>';
  const r = await api('mailGet');
  if (!r.ok || !r.list.length) { setBadge('mail', 0); return body.innerHTML = '<div class="empty"><i class="fa-solid fa-inbox"></i>Inbox is empty</div>'; }
  setBadge('mail', r.list.filter(m => !m.is_read).length);
  body.innerHTML = `<div class="list">${r.list.map((m, i) => `<div class="row" data-i="${i}">${m.is_read ? '' : '<span class="dot"></span>'}
    <div class="grow"><div class="title">${h(m.sender)}</div><div class="sub" style="color:var(--text)">${h(m.subject)}</div><div class="sub">${h(m.body)}</div></div><span class="meta">${ago(m.ts)}</span></div>`).join('')}</div>`;
  $$('.row', body).forEach(row => row.onclick = () => openApp('mailView', { title: 'Mail', mail: r.list[row.dataset.i] }));
};

Views.mailView = (body, { mail: m }) => {
  if (!m.is_read) { api('mailRead', { id: m.id }); m.is_read = 1; setBadge('mail', Math.max(0, (S.badges.mail || 1) - 1)); }
  setAction('fa-trash-can', async () => { await api('mailDelete', { id: m.id }); back(); });
  body.innerHTML = `<div class="card"><div style="font-size:18px;font-weight:700;margin-bottom:6px">${h(m.subject)}</div>
    <div style="color:var(--muted);font-size:12px;margin-bottom:14px">From ${h(m.sender)} · ${ago(m.ts)} ago</div>
    <div style="font-size:14px;line-height:1.5;white-space:pre-wrap;user-select:text">${h(m.body)}</div></div>`;
};

/* Notes */
Views.notes = async (body) => {
  setAction('fa-plus', () => openApp('noteEdit', { title: 'New Note', note: {} }));
  const r = await api('notesGet');
  if (!r.ok || !r.list.length) return body.innerHTML = '<div class="empty"><i class="fa-solid fa-note-sticky"></i>No notes</div>';
  body.innerHTML = `<div class="list">${r.list.map((n, i) => `<div class="row" data-i="${i}"><div class="grow"><div class="title">${h(n.title)}</div><div class="sub">${ago(n.ts)} · ${h(n.body.slice(0, 60))}</div></div></div>`).join('')}</div>`;
  $$('.row', body).forEach(row => row.onclick = () => openApp('noteEdit', { title: 'Note', note: r.list[row.dataset.i] }));
};

Views.noteEdit = (body, { note }) => {
  if (note.id) setAction('fa-trash-can', async () => { await api('notesDelete', { id: note.id }); back(); });
  body.innerHTML = `<input class="field" id="t" maxlength="80" placeholder="Title" value="${h(note.title || '')}" style="font-weight:700;font-size:16px">
    <textarea class="field" id="b" rows="14" placeholder="Start typing...">${h(note.body || '')}</textarea><button class="btn" id="save">Save</button>`;
  $('#save', body).onclick = async () => {
    const r = await api('notesSave', { id: note.id, title: $('#t', body).value, body: $('#b', body).value });
    if (!r.ok) return fail(r);
    toast('Notes', 'Saved', 'fa-check', '#34c759');
    back();
  };
};

/* Calculator */
Views.calculator = (body) => {
  let cur = '0', prev = null, op = null, fresh = true;
  const keys = [['AC', 'fn'], ['±', 'fn'], ['%', 'fn'], ['÷', 'op'], ['7'], ['8'], ['9'], ['×', 'op'], ['4'], ['5'], ['6'], ['−', 'op'], ['1'], ['2'], ['3'], ['+', 'op'], ['0', 'zero'], ['.'], ['=', 'op']];
  body.innerHTML = `<div class="calc-display" id="cd">0</div><div class="calc-keys">${keys.map(([k, c]) => `<button class="ck ${c || ''}" data-k="${k}">${k}</button>`).join('')}</div>`;
  const fmt = n => { const v = parseFloat(n); return Number.isFinite(v) ? (Math.abs(v) > 1e12 ? v.toExponential(4) : String(+v.toFixed(8))) : 'Error'; };
  const calc = (a, b, o) => ({ '+': a + b, '−': a - b, '×': a * b, '÷': b === 0 ? NaN : a / b }[o]);
  const show = () => { const d = $('#cd', body); d.textContent = cur; d.style.fontSize = cur.length > 9 ? '32px' : '48px'; };
  $$('.ck', body).forEach(b => b.onclick = () => {
    const k = b.dataset.k;
    if (/[0-9]/.test(k)) { cur = fresh || cur === '0' ? k : (cur.length < 14 ? cur + k : cur); fresh = false; }
    else if (k === '.') { if (fresh) { cur = '0.'; fresh = false; } else if (!cur.includes('.')) cur += '.'; }
    else if (k === 'AC') { cur = '0'; prev = null; op = null; fresh = true; }
    else if (k === '±') cur = fmt(-parseFloat(cur));
    else if (k === '%') cur = fmt(parseFloat(cur) / 100);
    else if (k === '=') { if (op != null && prev != null) { cur = fmt(calc(prev, parseFloat(cur), op)); prev = null; op = null; fresh = true; } }
    else { if (op && prev != null && !fresh) cur = fmt(calc(prev, parseFloat(cur), op)); prev = parseFloat(cur); op = k; fresh = true; }
    show();
  });
};

/* Garage */
Views.garage = async (body) => {
  body.innerHTML = '<div class="empty"><i class="fa-solid fa-spinner fa-spin"></i></div>';
  const r = await api('garageGet');
  if (!r.ok || !r.list.length) return body.innerHTML = '<div class="empty"><i class="fa-solid fa-car"></i>You don\'t own any vehicles</div>';
  const bar = (v, max, col) => { const pct = Math.max(0, Math.min(100, (Number(v) || 0) / max * 100)); return `<div class="bar"><div style="width:${pct}%;background:${col}"></div></div>`; };
  body.innerHTML = r.list.map(v => `<div class="card"><div style="display:flex;justify-content:space-between;align-items:center">
      <div><b style="text-transform:capitalize">${h(v.vehicle)}</b><div style="color:var(--muted);font-size:12px;margin-top:2px">${h(v.plate)} · ${h(v.garage || 'Unknown')}</div></div>
      <span class="pill" style="background:${h(v.stateColor)}22;color:${h(v.stateColor)}">${h(v.stateLabel)}</span></div>
      <div class="stats"><div>Fuel ${Math.round(v.fuel || 0)}%${bar(v.fuel, 100, '#ffcc00')}</div><div>Engine ${Math.round((v.engine || 0) / 10)}%${bar(v.engine, 1000, '#34c759')}</div><div>Body ${Math.round((v.body || 0) / 10)}%${bar(v.body, 1000, '#4f7cff')}</div></div></div>`).join('');
};

/* Services */
Views.services = (body) => {
  const list = S.profile.services || [];
  body.innerHTML = `<p style="color:var(--muted);font-size:13px;margin:0 2px 12px">Send an alert to on-duty units.</p>
    <div class="svc-grid">${list.map(s => `<button class="svc" data-job="${h(s.job)}"><i class="fa-solid ${h(s.icon)}" style="color:${h(s.color)}"></i>${h(s.label)}</button>`).join('')}</div>`;
  $$('.svc', body).forEach(b => b.onclick = () => openApp('serviceForm', { title: list.find(s => s.job === b.dataset.job).label, job: b.dataset.job }));
};

Views.serviceForm = (body, { job }) => {
  let share = true;
  body.innerHTML = `<label class="label">What's going on?</label><textarea class="field" id="m" rows="5" maxlength="300"></textarea>
    <div class="card" style="display:flex;justify-content:space-between;align-items:center"><span>Share my location</span><button class="switch on" id="sw"></button></div>
    <button class="btn" id="send">Send alert</button>`;
  $('#sw', body).onclick = e => { share = !share; e.target.classList.toggle('on', share); };
  $('#send', body).onclick = async () => {
    const r = await api('servicesSend', { job, text: $('#m', body).value, shareLocation: share });
    if (!r.ok) return fail(r);
    toast('Services', r.msg, 'fa-check', '#34c759');
    back();
  };
};

/* Settings */
Views.settings = (body) => {
  const st = S.profile.settings;
  body.innerHTML = `<div class="card" style="display:flex;gap:12px;align-items:center"><div class="avatar" style="width:52px;height:52px;font-size:18px">${h(initials(S.profile.name))}</div>
      <div><b>${h(S.profile.name)}</b><div style="color:var(--muted);font-size:12px">${h(S.profile.number)} · ${h(S.profile.job || '')}</div><div style="color:var(--muted);font-size:11px">CID ${h(S.profile.citizenid)}</div></div></div>
    <b style="display:block;margin:16px 2px 8px">Wallpaper</b>
    <div class="wp-grid">${WALLPAPERS.map(w => `<button class="wp screen wp-${w} ${st.wallpaper === w ? 'active' : ''}" data-w="${w}"></button>`).join('')}</div>
    <div class="list" style="margin-top:16px"><div class="row" style="cursor:default"><div class="grow"><div class="title">Do not disturb</div><div class="sub">Hide in-phone notifications</div></div><button class="switch ${st.muted ? 'on' : ''}" id="mute"></button></div></div>`;
  const save = () => api('settingsSave', st);
  $$('.wp', body).forEach(b => b.onclick = () => {
    st.wallpaper = b.dataset.w; applyWallpaper();
    $$('.wp', body).forEach(x => x.classList.toggle('active', x === b)); save();
  });
  $('#mute', body).onclick = e => { st.muted = !st.muted; e.target.classList.toggle('on', st.muted); save(); };
};

function applyWallpaper() {
  const sc = $('#screen');
  WALLPAPERS.forEach(w => sc.classList.remove('wp-' + w));
  sc.classList.add('wp-' + (S.profile.settings.wallpaper || 'aurora'));
}

/* ---------- calls ---------- */
function showCall(number, status, mode) {
  S.call = { number, mode };
  $('#callName').textContent = display(number);
  $('#callStatus').textContent = status;
  const btns = $('#callButtons');
  btns.innerHTML = mode === 'incoming'
    ? '<button class="decline" id="cDecline"><i class="fa-solid fa-phone"></i></button><button class="accept" id="cAccept"><i class="fa-solid fa-phone"></i></button>'
    : '<button class="decline" id="cDecline"><i class="fa-solid fa-phone"></i></button>';
  $('#cDecline').onclick = () => { api('callEnd'); hideCall(); };
  const acc = $('#cAccept');
  if (acc) acc.onclick = async () => { const r = await api('callAccept'); if (!r.ok) hideCall(); };
  $('#callScreen').classList.remove('hidden');
}
function hideCall() {
  clearInterval(S.callTimer); S.callTimer = null; S.call = null;
  $('#callScreen').classList.add('hidden');
}
function startCallTimer() {
  const start = Date.now();
  $('#callButtons').innerHTML = '<button class="decline" id="cDecline"><i class="fa-solid fa-phone"></i></button>';
  $('#cDecline').onclick = () => { api('callEnd'); hideCall(); };
  const tick = () => { const s = Math.floor((Date.now() - start) / 1000); $('#callStatus').textContent = `${String(Math.floor(s / 60)).padStart(2, '0')}:${String(s % 60).padStart(2, '0')}`; };
  tick(); S.callTimer = setInterval(tick, 1000);
}
async function startCall(number) {
  showCall(number, 'Calling…', 'outgoing');
  const r = await api('callStart', { number });
  if (!r.ok) { $('#callStatus').textContent = r.msg || 'Call failed'; setTimeout(hideCall, 1800); }
}

/* ---------- server pushes ---------- */
const Push = {
  message(d) {
    if (S.current?.id === 'chat' && S.chatAppend && S.chatAppend(d.from, d.text, d.ts)) return;
    setBadge('messages', (S.badges.messages || 0) + 1);
    toast(display(d.from), d.text, 'fa-comment', '#28c75a', () => openApp('chat', { title: display(d.from), number: d.from }));
  },
  mail(d) { setBadge('mail', (S.badges.mail || 0) + 1); toast('Mail · ' + (d.sender || ''), d.subject || '', 'fa-envelope', '#2563eb', () => openApp('mail')); },
  bank(d) { toast('Fleeca', d.text, 'fa-building-columns', '#0e8f4e'); },
  chirp(d) { if (S.current?.id === 'chirp' && S.chirpReload) S.chirpReload(); else toast('Chirp · ' + d.author, d.content, 'fa-feather', '#1374e0'); },
  dispatch(d) {
    toast(d.service + ' alert', `${d.name}: ${d.text}`, 'fa-tower-broadcast', '#5f3dc4', d.coords ? () => post('setWaypoint', d.coords) : null);
  },
  incomingCall(d) { showCall(d.number, 'Incoming call…', 'incoming'); },
  callAccepted() { if (S.call) startCallTimer(); },
  callEnded(d) { if (S.call) { $('#callStatus').textContent = d.reason || 'Call ended'; clearInterval(S.callTimer); setTimeout(hideCall, 1200); } },
};

/* ---------- lifecycle ---------- */
function open(profile) {
  S.profile = profile;
  S.contacts = profile.contacts || [];
  S.badges = { ...(profile.badges || {}) };
  applyWallpaper();
  $('#phone').classList.remove('hidden');
  if (!S.current) { goHome(); renderHome(); }
  else renderHome();
}
function close() { $('#phone').classList.add('hidden'); }

window.addEventListener('message', e => {
  const d = e.data || {};
  if (d.action === 'open') open(d.profile);
  else if (d.action === 'close') close();
  else if (d.action === 'push' && Push[d.kind]) Push[d.kind](d.data || {});
});

document.addEventListener('keydown', e => {
  if (e.key === 'Escape') post('close');
  if (e.key === 'Backspace' && !['INPUT', 'TEXTAREA'].includes(document.activeElement.tagName) && S.current) back();
});

$('#backBtn').onclick = back;
$('#homeBar').onclick = goHome;

function tickClock() {
  const d = new Date();
  const t = d.toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit' }).replace(/ ?[AP]M/, '');
  $('#clock').textContent = t; $('#bigClock').textContent = t;
  $('#bigDate').textContent = d.toLocaleDateString('en-US', { weekday: 'long', month: 'long', day: 'numeric' });
}
tickClock(); setInterval(tickClock, 10000);

/* ---------- browser preview (mock server) ---------- */
const Mock = {
  now: () => Math.floor(Date.now() / 1000),
  data: {
    contacts: [{ id: 1, name: 'Tony Rizzo', number: '555-0182' }, { id: 2, name: 'Lisa Park', number: '555-0124' }, { id: 3, name: 'Mechanic Joe', number: '555-0177' }],
    notes: [{ id: 1, title: 'Shopping list', body: 'Lockpicks\nRepair kit\nSandwich', ts: 0 }],
  },
  handle(endpoint, { action, payload = {} } = {}) {
    const n = this.now(), D = this.data;
    if (endpoint !== 'request') return { ok: true };
    const r = {
      contactsGet: { ok: true, list: D.contacts },
      contactsAdd: (D.contacts.push({ id: Date.now(), ...payload }), { ok: true }),
      contactsDelete: { ok: true },
      messagesThreads: { ok: true, list: [{ number: '555-0182', last: 'Meet me at the pier at 9', ts: n - 300, unread: 2 }, { number: '555-0124', last: 'Thanks!', ts: n - 7200, unread: 0 }] },
      messagesGet: { ok: true, list: [{ mine: false, text: 'You around?', ts: n - 600 }, { mine: true, text: 'Yeah what\'s up', ts: n - 500 }, { mine: false, text: 'Meet me at the pier at 9', ts: n - 300 }] },
      messagesSend: { ok: true, ts: n },
      callHistory: { ok: true, list: [{ number: '555-0124', outgoing: true, status: 'answered', ts: n - 4000 }, { number: '555-0199', outgoing: false, status: 'missed', ts: n - 9000 }] },
      callStart: { ok: false, msg: 'The number you dialed is unavailable' },
      bankGet: { ok: true, bank: 48250, cash: 1320, log: [{ label: 'Transfer from Lisa Park', amount: 500, ts: n - 3600 }, { label: 'Yellow Pages ad', amount: -50, ts: n - 86400 }] },
      bankTransfer: { ok: true },
      chirpGet: { ok: true, list: [{ id: 2, author: 'Lisa Park', handle: '@lisa_park', content: 'Traffic on Route 68 is insane right now 🚗', likes: 12, liked: 1, ts: n - 900 }, { id: 1, author: 'Tony Rizzo', handle: '@tony_rizzo', content: 'Pizza This is hiring. DM me.', likes: 3, ts: n - 5400, mine: 0 }] },
      chirpLike: { ok: true, liked: true, likes: 13 },
      adsGet: { ok: true, list: [{ id: 1, title: 'Selling Sultan RS', body: 'Clean title, full upgrades. Serious buyers only.', price: 85000, author: 'Tony Rizzo', number: '555-0182', ts: n - 2000 }] },
      mailGet: { ok: true, list: [{ id: 1, sender: 'Los Santos DMV', subject: 'Your license is ready', body: 'Pick up your driver license at City Hall.', is_read: 0, ts: n - 1000 }] },
      notesGet: { ok: true, list: D.notes },
      notesSave: { ok: true },
      garageGet: { ok: true, list: [{ vehicle: 'sultan', plate: 'NOVA 123', state: 1, garage: 'Legion Square', fuel: 74, engine: 920, body: 870, stateLabel: 'Garaged', stateColor: '#34c759' }, { vehicle: 'bati', plate: 'FAST 01', state: 0, garage: 'Pillbox', fuel: 22, engine: 610, body: 400, stateLabel: 'Out', stateColor: '#ff9500' }] },
      servicesSend: { ok: true, msg: 'Alert sent to 2 Police unit(s)' },
    }[action];
    return Promise.resolve(r || { ok: true });
  },
};

if (DEV) {
  document.body.style.background = '#3a3f4b';
  open({
    ok: true, name: 'Alex Morgan', number: '555-0100', citizenid: 'ABC12345', bank: 48250, cash: 1320, job: 'Mechanic',
    settings: { wallpaper: 'aurora', muted: false }, contacts: Mock.data.contacts, badges: { messages: 2, mail: 1 },
    services: [{ job: 'police', label: 'Police', icon: 'fa-shield-halved', color: '#2f6bff' }, { job: 'ambulance', label: 'EMS', icon: 'fa-truck-medical', color: '#ff3b30' }, { job: 'mechanic', label: 'Mechanic', icon: 'fa-wrench', color: '#ff9500' }, { job: 'taxi', label: 'Taxi', icon: 'fa-taxi', color: '#ffcc00' }],
    chirpMax: 280, adCost: 50,
  });
}

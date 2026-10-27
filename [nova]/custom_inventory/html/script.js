/* custom_inventory — NUI */

const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : null;

const state = {
    defs: {},
    hotbarSlots: 5,
    player: null,
    secondary: null,
    drag: null,
};

const $ = (sel, root = document) => root.querySelector(sel);
const app = $('#app');
const panels = { player: $('#panel-player'), secondary: $('#panel-secondary') };
const ghost = $('#ghost');
const tooltip = $('#tooltip');
const amountInput = $('#amount');
const GROUND_ID = '__ground';

// ─── Bridge ──────────────────────────────────────────────────────

function post(name, data = {}) {
    if (!RES) return mock(name, data);
    fetch(`https://${RES}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data),
    }).catch(() => {});
}

window.addEventListener('message', (e) => {
    const d = e.data;
    switch (d.action) {
        case 'init':
            state.defs = d.items || {};
            state.hotbarSlots = d.hotbarSlots || 5;
            break;
        case 'open':
            state.player = normalize(d.player);
            state.secondary = normalize(d.secondary);
            renderAll();
            app.classList.remove('hidden');
            $('#hotbar').classList.add('hidden');
            break;
        case 'close':
            closeUI(false);
            break;
        case 'update': {
            const inv = normalize(d.inventory);
            if (state.player && inv.id === state.player.id) state.player = inv;
            else if (state.secondary && inv.id === state.secondary.id) state.secondary = inv;
            renderAll();
            break;
        }
        case 'setSecondary':
            state.secondary = normalize(d.inventory);
            renderAll();
            break;
        case 'hotbar':
            showHotbar(normalize(d.inventory));
            break;
        case 'notify':
            toast(d.message, d.kind);
            break;
        case 'progress':
            progress(d.label, d.duration);
            break;
        case 'progressEnd':
            progressEnd(d.cancelled);
            break;
    }
});

// Lua may send items as an array or an object — always get an array
function normalize(inv) {
    if (!inv) return null;
    const items = Array.isArray(inv.items) ? inv.items : Object.values(inv.items || {});
    return { ...inv, items };
}

function itemAt(inv, slot) {
    return inv && inv.items.find((i) => i.slot === slot);
}

function def(name) {
    return state.defs[name] || { label: name, weight: 0 };
}

// ─── Rendering ───────────────────────────────────────────────────

function renderAll() {
    renderPanel(panels.player, state.player, 'player');
    renderPanel(panels.secondary, state.secondary, 'secondary');
}

function kg(g) { return (g / 1000).toFixed(g % 1000 === 0 ? 0 : g < 100 ? 2 : 1); }

function renderPanel(panel, inv, side) {
    const grid = $('[data-role=grid]', panel);
    const title = $('[data-role=title]', panel);
    const weightText = $('[data-role=weight]', panel);
    const bar = $('[data-role=bar]', panel);
    const eyebrow = $('[data-role=eyebrow]', panel);
    grid.innerHTML = '';

    if (!inv) {
        // No container open: show an empty "ground" grid you can drop into
        title.textContent = 'Ground';
        if (eyebrow) eyebrow.textContent = 'Drag here to drop';
        weightText.textContent = '';
        bar.style.width = '0';
        bar.parentElement.style.visibility = 'hidden';
        for (let s = 1; s <= 20; s++) grid.appendChild(makeSlot(GROUND_ID, s, null, false));
        return;
    }

    title.textContent = inv.label;
    if (eyebrow) eyebrow.textContent = { stash: 'Stash', trunk: 'Vehicle', glovebox: 'Vehicle', drop: 'Ground', shop: 'Shop' }[inv.type] || 'Container';

    if (inv.type === 'shop') {
        weightText.textContent = 'Drag to buy';
        bar.parentElement.style.visibility = 'hidden';
    } else {
        bar.parentElement.style.visibility = 'visible';
        weightText.textContent = `${kg(inv.weight)} / ${kg(inv.maxWeight)} kg`;
        const pct = Math.min(100, (inv.weight / inv.maxWeight) * 100);
        bar.style.width = pct + '%';
        bar.classList.toggle('full', pct >= 90);
    }

    for (let s = 1; s <= inv.slots; s++) {
        grid.appendChild(makeSlot(inv.id, s, itemAt(inv, s), side === 'player' && s <= state.hotbarSlots, inv.type));
    }
}

function makeSlot(invId, slot, item, hot, invType) {
    const el = document.createElement('div');
    el.className = 'slot' + (item ? ' filled' : '') + (hot ? ' hot' : '');
    el.dataset.inv = invId;
    el.dataset.slot = slot;
    if (hot) el.insertAdjacentHTML('beforeend', `<span class="num">${slot}</span>`);
    if (item) fillSlot(el, item, invType);
    return el;
}

function fillSlot(el, item, invType) {
    const d = def(item.name);
    const img = document.createElement('img');
    img.src = `images/${item.name}.png`;
    img.onerror = () => {
        const g = document.createElement('div');
        g.className = 'glyph';
        g.textContent = (d.label || item.name).charAt(0).toUpperCase();
        img.replaceWith(g);
    };
    el.appendChild(img);
    if (invType === 'shop') {
        el.insertAdjacentHTML('beforeend', `<span class="price">$${item.price}</span>`);
    } else if (item.count > 1 || d.stack) {
        el.insertAdjacentHTML('beforeend', `<span class="count">${item.count.toLocaleString()}x</span>`);
    }
    const label = document.createElement('div');
    label.className = 'label';
    label.textContent = d.label;
    el.appendChild(label);
}

function invById(id) {
    if (state.player && state.player.id === id) return state.player;
    if (state.secondary && state.secondary.id === id) return state.secondary;
    return null;
}

// ─── Drag & drop ────────────────────────────────────────────────

function wantedCount(item, e, invType) {
    if (invType === 'shop') {
        const n = parseInt(amountInput.value, 10);
        return n > 0 ? n : 1;
    }
    if (e.shiftKey) return Math.max(1, Math.floor(item.count / 2));
    if (e.ctrlKey) return 1;
    const n = parseInt(amountInput.value, 10);
    return n > 0 ? Math.min(n, item.count) : item.count;
}

document.addEventListener('mousedown', (e) => {
    if (e.button !== 0) return;
    const el = e.target.closest('.slot.filled');
    if (!el || el.closest('#hotbar')) return;
    const inv = invById(el.dataset.inv);
    const item = itemAt(inv, +el.dataset.slot);
    if (!item) return;
    state.drag = { el, inv, item, x: e.clientX, y: e.clientY, started: false };
});

document.addEventListener('mousemove', (e) => {
    const drag = state.drag;
    if (drag) {
        if (!drag.started && Math.hypot(e.clientX - drag.x, e.clientY - drag.y) > 4) {
            drag.started = true;
            drag.el.classList.add('dragging');
            ghost.className = 'slot filled';
            ghost.id = 'ghost';
            ghost.innerHTML = '';
            fillSlot(ghost, drag.item, drag.inv.type);
            hideTooltip();
        }
        if (drag.started) {
            ghost.style.left = e.clientX + 'px';
            ghost.style.top = e.clientY + 'px';
            document.querySelectorAll('.drop-target').forEach((n) => n.classList.remove('drop-target'));
            const t = dropTargetAt(e.clientX, e.clientY);
            if (t) t.classList.add('drop-target');
        }
        return;
    }
    updateTooltip(e);
});

document.addEventListener('mouseup', (e) => {
    const drag = state.drag;
    state.drag = null;
    if (!drag || !drag.started) return;
    drag.el.classList.remove('dragging');
    ghost.classList.add('hidden');
    document.querySelectorAll('.drop-target').forEach((n) => n.classList.remove('drop-target'));

    const target = dropTargetAt(e.clientX, e.clientY);
    if (!target) return;
    const count = wantedCount(drag.item, e, drag.inv.type);
    const fromPlayer = drag.inv === state.player;

    if (target.classList.contains('action')) {
        if (!fromPlayer) return toast('Move it to your pockets first.', 'error');
        const action = target.dataset.action;
        if (action === 'use') post('use', { slot: drag.item.slot });
        else post(action, { slot: drag.item.slot, count });
        return;
    }

    if (target.dataset.inv === GROUND_ID) {
        if (fromPlayer) post('drop', { slot: drag.item.slot, count });
        return;
    }

    post('move', {
        fromInv: drag.inv.id, fromSlot: drag.item.slot,
        toInv: target.dataset.inv, toSlot: +target.dataset.slot,
        count,
    });
});

function dropTargetAt(x, y) {
    const el = document.elementFromPoint(x, y);
    if (!el) return null;
    const slot = el.closest('#app .slot');
    if (slot) return slot;
    return el.closest('.action');
}

// Right-click = use
document.addEventListener('contextmenu', (e) => {
    e.preventDefault();
    const el = e.target.closest('#panel-player .slot.filled');
    if (el) post('use', { slot: +el.dataset.slot });
});

// Double-click = quick move to the other side
document.addEventListener('dblclick', (e) => {
    const el = e.target.closest('#app .slot.filled');
    if (!el) return;
    const from = invById(el.dataset.inv);
    const item = itemAt(from, +el.dataset.slot);
    const to = from === state.player ? state.secondary : state.player;
    if (!item) return;
    if (!to) return post('drop', { slot: item.slot, count: wantedCount(item, e) });
    if (to.type === 'shop') return;

    const d = def(item.name);
    let target = d.stack && to.items.find((i) => i.name === item.name && isPlain(i) && isPlain(item));
    let slot = target ? target.slot : null;
    if (!slot) {
        for (let s = 1; s <= to.slots; s++) if (!itemAt(to, s)) { slot = s; break; }
    }
    if (!slot) return toast('No free slot.', 'error');
    post('move', { fromInv: from.id, fromSlot: item.slot, toInv: to.id, toSlot: slot, count: wantedCount(item, e, from.type) });
});

function isPlain(i) { return !i.metadata || Object.keys(i.metadata).length === 0; }

// ─── Tooltip ─────────────────────────────────────────────────────

function updateTooltip(e) {
    const el = e.target.closest && e.target.closest('#app .slot.filled');
    if (!el) return hideTooltip();
    const inv = invById(el.dataset.inv);
    const item = itemAt(inv, +el.dataset.slot);
    if (!item) return hideTooltip();
    const d = def(item.name);

    let html = `<h4>${escapeHtml(d.label)}</h4>`;
    if (d.description) html += `<div>${escapeHtml(d.description)}</div>`;
    html += '<div class="meta">';
    if (inv.type === 'shop') html += `Price: <b>$${item.price}</b> each<br>`;
    html += `Weight: <b>${kg(d.weight * (inv.type === 'shop' ? 1 : item.count))} kg</b>`;
    if (d.usable && inv === state.player) html += ' · <b>Usable</b>';
    if (item.metadata) {
        for (const [k, v] of Object.entries(item.metadata)) {
            if (typeof v !== 'object') html += `<br>${escapeHtml(k)}: <b>${escapeHtml(String(v))}</b>`;
        }
    }
    html += '</div>';
    tooltip.innerHTML = html;
    tooltip.classList.remove('hidden');

    const pad = 16;
    let x = e.clientX + pad, y = e.clientY + pad;
    const r = tooltip.getBoundingClientRect();
    if (x + r.width > innerWidth) x = e.clientX - r.width - pad;
    if (y + r.height > innerHeight) y = e.clientY - r.height - pad;
    tooltip.style.left = x + 'px';
    tooltip.style.top = y + 'px';
}

function hideTooltip() { tooltip.classList.add('hidden'); }

function escapeHtml(s) {
    return String(s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
}

// ─── Hotbar, toasts, progress ───────────────────────────────────

let hotbarTimer;
function showHotbar(inv) {
    if (!inv || !app.classList.contains('hidden')) return;
    const bar = $('#hotbar');
    bar.innerHTML = '';
    for (let s = 1; s <= state.hotbarSlots; s++) bar.appendChild(makeSlot(inv.id, s, itemAt(inv, s), true));
    bar.classList.remove('hidden');
    clearTimeout(hotbarTimer);
    hotbarTimer = setTimeout(() => bar.classList.add('hidden'), 2500);
}

function toast(message, kind = 'info') {
    const el = document.createElement('div');
    el.className = `toast ${kind}`;
    el.textContent = message;
    $('#toasts').appendChild(el);
    setTimeout(() => el.classList.add('out'), 3200);
    setTimeout(() => el.remove(), 3500);
}

let progressAnim;
function progress(label, duration) {
    const p = $('#progress');
    p.classList.remove('hidden', 'cancelled');
    $('span', p).textContent = label;
    const fill = $('.bar i', p);
    fill.style.transition = 'none';
    fill.style.width = '0';
    cancelAnimationFrame(progressAnim);
    progressAnim = requestAnimationFrame(() => {
        fill.style.transition = `width ${duration}ms linear`;
        fill.style.width = '100%';
    });
}

function progressEnd(cancelled) {
    const p = $('#progress');
    if (cancelled) {
        p.classList.add('cancelled');
        $('span', p).textContent = 'Cancelled';
        $('.bar i', p).style.transition = 'none';
    }
    setTimeout(() => p.classList.add('hidden'), cancelled ? 900 : 150);
}

// ─── Closing ─────────────────────────────────────────────────────

function closeUI(notifyClient = true) {
    app.classList.add('hidden');
    hideTooltip();
    ghost.classList.add('hidden');
    state.drag = null;
    amountInput.value = 0;
    if (notifyClient) post('close');
}

document.addEventListener('keydown', (e) => {
    if (app.classList.contains('hidden') || e.repeat) return;
    if (e.key === 'Escape' || e.key === 'Tab') {
        e.preventDefault();
        closeUI(true);
    }
});

// ─── Browser preview (only when opened outside FiveM) ───────────

function mock(name, data) {
    const p = state.player, s = state.secondary;
    if (name === 'close') return setTimeout(() => window.postMessage({ action: 'open', player: p, secondary: s }), 600);
    if (name === 'move') {
        const from = invById(data.fromInv), to = invById(data.toInv);
        const a = itemAt(from, data.fromSlot), b = itemAt(to, data.toSlot);
        if (from.type === 'shop') return toast(`Bought ${data.count}x ${def(a.name).label}`, 'success');
        if (b && b.name === a.name && def(a.name).stack) { b.count += data.count; a.count -= data.count; }
        else if (!b && data.count < a.count) { to.items.push({ ...a, slot: data.toSlot, count: data.count }); a.count -= data.count; }
        else if (!b) { from.items = from.items.filter((i) => i !== a); a.slot = data.toSlot; to.items.push(a); }
        else { from.items = from.items.filter((i) => i !== a); to.items = to.items.filter((i) => i !== b); a.slot = data.toSlot; b.slot = data.fromSlot; to.items.push(a); from.items.push(b); }
        from.items = from.items.filter((i) => i.count > 0);
        renderAll();
    } else {
        toast(`${name} → slot ${data.slot}`, 'info');
    }
}

if (!RES) {
    const items = {
        money: { label: 'Cash', weight: 0, stack: true, description: 'Cold, hard cash.' },
        water: { label: 'Water', weight: 500, stack: true, description: 'A bottle of water.', usable: true },
        burger: { label: 'Burger', weight: 350, stack: true, description: 'Greasy, but it does the job.', usable: true },
        bandage: { label: 'Bandage', weight: 115, stack: true, description: 'Restores a little health.', usable: true },
        phone: { label: 'Phone', weight: 190, stack: false, description: 'A smartphone.' },
        radio: { label: 'Radio', weight: 600, stack: false, description: 'Handheld two-way radio.' },
        id_card: { label: 'ID Card', weight: 10, stack: false, description: 'Identification.' },
        scrap_metal: { label: 'Scrap Metal', weight: 1000, stack: true },
    };
    window.postMessage({ action: 'init', items, hotbarSlots: 5 });
    window.postMessage({
        action: 'open',
        player: {
            id: 'player:demo', type: 'player', label: 'John Doe', slots: 40, maxWeight: 30000, weight: 6890,
            items: [
                { slot: 1, name: 'phone', count: 1 }, { slot: 2, name: 'water', count: 3 },
                { slot: 3, name: 'burger', count: 2 }, { slot: 6, name: 'money', count: 1250 },
                { slot: 7, name: 'id_card', count: 1, metadata: { name: 'John Doe', dob: '1994-03-12' } },
                { slot: 8, name: 'scrap_metal', count: 5 },
            ],
        },
        secondary: {
            id: 'trunk:ABC123', type: 'trunk', label: 'Trunk ABC123', slots: 20, maxWeight: 60000, weight: 12600,
            items: [{ slot: 1, name: 'scrap_metal', count: 12 }, { slot: 4, name: 'radio', count: 1 }],
        },
    });
    document.body.style.background = 'linear-gradient(135deg, #4a5466, #262b33)';
}

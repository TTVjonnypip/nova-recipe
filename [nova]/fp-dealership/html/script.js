const $ = (id) => document.getElementById(id);

const state = {
    vehicles: [],
    category: 'All',
    search: '',
    selected: null,   // vehicle object
    isAdmin: false,
    currency: '$',
    tab: 'browse',
    confirmBuy: null, // 'cash' | 'bank' while waiting for the second click
    busy: false,
};

let confirmTimer = null;
let toastTimer = null;

/* ---------- helpers ---------- */
function post(name, data = {}) {
    return fetch(`https://${GetParentResourceName()}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data),
    }).then((r) => r.json()).catch(() => ({}));
}

function money(n) {
    return state.currency + Number(n || 0).toLocaleString();
}

function el(tag, className, text) {
    const e = document.createElement(tag);
    if (className) e.className = className;
    if (text !== undefined) e.textContent = text;
    return e;
}

function toast(message, ok = false) {
    const t = $('toast');
    t.textContent = message;
    t.classList.toggle('ok', ok);
    t.classList.remove('hidden');
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => t.classList.add('hidden'), 3500);
}

/* ---------- rendering ---------- */
function categories() {
    const set = new Set(state.vehicles.map((v) => v.category));
    return ['All', ...Array.from(set)];
}

function filtered() {
    const q = state.search.trim().toLowerCase();
    return state.vehicles.filter((v) => {
        const inCat = state.category === 'All' || v.category === state.category;
        const inSearch = !q || v.label.toLowerCase().includes(q) || v.model.toLowerCase().includes(q);
        return inCat && inSearch;
    });
}

function renderCategories() {
    const wrap = $('categories');
    wrap.replaceChildren();
    const cats = categories();
    if (!cats.includes(state.category)) state.category = 'All';

    cats.forEach((c) => {
        const b = el('button', 'chip' + (c === state.category ? ' active' : ''), c);
        b.addEventListener('click', () => {
            state.category = c;
            renderCategories();
            renderList();
        });
        wrap.appendChild(b);
    });

    const dl = $('catList');
    dl.replaceChildren();
    cats.filter((c) => c !== 'All').forEach((c) => {
        const o = document.createElement('option');
        o.value = c;
        dl.appendChild(o);
    });
}

function renderList() {
    const list = $('list');
    list.replaceChildren();
    const items = filtered();

    if (!items.length) {
        list.appendChild(el('li', 'empty', state.vehicles.length
            ? 'No vehicles match your search.'
            : 'No vehicles for sale right now.'));
        return;
    }

    items.forEach((v) => {
        const li = el('li', 'car' + (state.selected && state.selected.model === v.model ? ' selected' : ''));
        const left = el('div');
        left.appendChild(el('div', 'name', v.label));
        left.appendChild(el('div', 'sub', v.category));
        li.appendChild(left);
        li.appendChild(el('div', 'price', money(v.price)));
        li.addEventListener('click', () => selectVehicle(v));
        list.appendChild(li);
    });
}

function renderManage() {
    const list = $('manageList');
    list.replaceChildren();

    if (!state.vehicles.length) {
        list.appendChild(el('li', 'empty', 'The dealership is empty. Add a vehicle above.'));
        return;
    }

    state.vehicles.forEach((v) => {
        const li = el('li', 'car');
        const left = el('div');
        left.appendChild(el('div', 'name', v.label));
        left.appendChild(el('div', 'sub', `${v.model} \u2022 ${v.category} \u2022 ${money(v.price)}`));
        li.appendChild(left);

        const rm = el('button', 'remove', 'Remove');
        let armed = false;
        rm.addEventListener('click', async (e) => {
            e.stopPropagation();
            if (!armed) {
                armed = true;
                rm.textContent = 'Confirm';
                rm.classList.add('confirm');
                setTimeout(() => {
                    armed = false;
                    rm.textContent = 'Remove';
                    rm.classList.remove('confirm');
                }, 3000);
                return;
            }
            const res = await post('removeVehicle', { model: v.model });
            toast(res.message || 'Done.', !!res.success);
            if (res.vehicles) applyVehicles(res.vehicles);
        });
        li.appendChild(rm);

        // Click a row to load it into the form for editing
        li.addEventListener('click', () => {
            $('fModel').value = v.model;
            $('fLabel').value = v.label;
            $('fPrice').value = v.price;
            $('fCategory').value = v.category;
            $('saveBtn').textContent = 'Update vehicle';
        });

        list.appendChild(li);
    });
}

function renderDetail() {
    const d = $('detail');
    resetBuyButtons();
    if (!state.selected) {
        d.classList.add('hidden');
        return;
    }
    $('dName').textContent = state.selected.label;
    const meta = $('dMeta');
    meta.replaceChildren();
    meta.appendChild(el('b', null, money(state.selected.price)));
    meta.appendChild(document.createTextNode(state.selected.category));
    d.classList.remove('hidden');
}

function resetBuyButtons() {
    clearTimeout(confirmTimer);
    state.confirmBuy = null;
    const cash = $('buyCash'), bank = $('buyBank');
    cash.textContent = 'Pay with cash';
    bank.textContent = 'Pay with bank';
    cash.classList.add('primary'); cash.classList.remove('confirm');
    bank.classList.remove('confirm');
}

function renderAll() {
    renderCategories();
    renderList();
    renderManage();
    renderDetail();
}

/* ---------- actions ---------- */
function selectVehicle(v) {
    state.selected = v;
    renderList();
    renderDetail();
    post('preview', { model: v.model });
}

function applyVehicles(vehicles) {
    state.vehicles = vehicles;
    if (state.selected) {
        const still = vehicles.find((v) => v.model === state.selected.model);
        if (still) {
            state.selected = still;
        } else {
            state.selected = null;
            post('preview', { model: null });
        }
    }
    renderAll();
}

function setTab(tab) {
    state.tab = tab;
    document.querySelectorAll('.tab').forEach((t) => t.classList.toggle('active', t.dataset.tab === tab));
    $('tab-browse').classList.toggle('hidden', tab !== 'browse');
    $('tab-manage').classList.toggle('hidden', tab !== 'manage');
}

async function buy(method) {
    if (!state.selected || state.busy) return;

    // First click arms the button, second click buys
    if (state.confirmBuy !== method) {
        resetBuyButtons();
        state.confirmBuy = method;
        const btn = method === 'cash' ? $('buyCash') : $('buyBank');
        btn.textContent = `Confirm ${money(state.selected.price)}`;
        btn.classList.add('confirm');
        btn.classList.remove('primary');
        confirmTimer = setTimeout(resetBuyButtons, 4000);
        return;
    }

    state.busy = true;
    $('buyCash').disabled = true;
    $('buyBank').disabled = true;

    const res = await post('buy', { model: state.selected.model, method });

    state.busy = false;
    $('buyCash').disabled = false;
    $('buyBank').disabled = false;
    resetBuyButtons();

    if (res && res.success === false) toast(res.message || 'Purchase failed.');
}

async function saveVehicle() {
    const payload = {
        model: $('fModel').value.trim(),
        label: $('fLabel').value.trim(),
        price: $('fPrice').value,
        category: $('fCategory').value.trim(),
    };
    const res = await post('saveVehicle', payload);
    toast(res.message || 'Done.', !!res.success);
    if (res.success && res.vehicles) {
        applyVehicles(res.vehicles);
        ['fModel', 'fLabel', 'fPrice', 'fCategory'].forEach((id) => { $(id).value = ''; });
        $('saveBtn').textContent = 'Add vehicle';
    }
}

/* ---------- events ---------- */
$('closeBtn').addEventListener('click', () => post('close'));
$('search').addEventListener('input', (e) => { state.search = e.target.value; renderList(); });
$('saveBtn').addEventListener('click', saveVehicle);
$('buyCash').addEventListener('click', () => buy('cash'));
$('buyBank').addEventListener('click', () => buy('bank'));
document.querySelectorAll('.tab').forEach((t) => t.addEventListener('click', () => setTab(t.dataset.tab)));

// Editing the model field again means a new vehicle, not an update
$('fModel').addEventListener('input', () => { $('saveBtn').textContent = 'Add vehicle'; });

document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') post('close');
});

// Drag the showroom area to rotate the car
let dragging = false;
let lastX = 0;
$('stage').addEventListener('mousedown', (e) => { dragging = true; lastX = e.clientX; });
window.addEventListener('mouseup', () => { dragging = false; });
window.addEventListener('mousemove', (e) => {
    if (!dragging) return;
    const dx = e.clientX - lastX;
    lastX = e.clientX;
    if (dx) post('rotate', { delta: dx * 0.6 });
});

/* ---------- messages from the game ---------- */
window.addEventListener('message', (event) => {
    const data = event.data;

    if (data.action === 'open') {
        state.currency = data.currency || '$';
        state.isAdmin = !!data.isAdmin;
        state.vehicles = data.vehicles || [];
        state.selected = null;
        state.category = 'All';
        state.search = '';
        $('search').value = '';
        $('shopName').textContent = data.name || 'Dealership';
        $('cash').textContent = money(data.cash);
        $('bank').textContent = money(data.bank);
        $('manageTab').classList.toggle('hidden', !state.isAdmin);
        setTab('browse');
        renderAll();
        $('app').classList.remove('hidden');
        if (state.vehicles.length) selectVehicle(state.vehicles[0]);
    }

    if (data.action === 'close') {
        $('app').classList.add('hidden');
        $('toast').classList.add('hidden');
        state.selected = null;
        resetBuyButtons();
    }
});

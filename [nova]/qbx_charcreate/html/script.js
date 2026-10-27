const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'qbx_charcreate';
const $ = (id) => document.getElementById(id);

const state = {
    characters: [],
    maxSlots: 3,
    allowDelete: true,
    selected: null, // { type: 'char', char } | { type: 'new' }
    busy: false,
};

async function post(name, data = {}) {
    try {
        const res = await fetch(`https://${RES}/${name}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(data),
        });
        return await res.json();
    } catch { return null; }
}

const money = (n) => '$' + Number(n || 0).toLocaleString('en-US');
const fmtDate = (s) => {
    const [y, m, d] = (s || '').split('-');
    return y && m && d ? `${m}/${d}/${y}` : s || '—';
};
const escapeHtml = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
}[c]));

// ── Render slots ────────────────────────────────
function renderSlots() {
    const list = $('slots');
    list.innerHTML = '';
    const total = Math.max(state.maxSlots, state.characters.length);

    for (let i = 0; i < total; i++) {
        const char = state.characters[i];
        const li = document.createElement('li');
        li.className = 'slot';
        li.style.animationDelay = `${i * 40}ms`;

        if (char) {
            li.innerHTML = `
                <span class="num">${String(i + 1).padStart(2, '0')}</span>
                <span class="meta">
                    <span class="name">${escapeHtml(char.firstname)} ${escapeHtml(char.lastname)}</span>
                    <span class="sub">${escapeHtml(char.job)} · ${money(char.bank + char.cash)}</span>
                </span>`;
            if (state.selected?.type === 'char' && state.selected.char.citizenid === char.citizenid) li.classList.add('active');
            li.onclick = () => selectCharacter(char);
        } else {
            li.classList.add('empty');
            li.innerHTML = `
                <span class="num">+</span>
                <span class="meta">
                    <span class="name">Create new character</span>
                    <span class="sub">Empty slot</span>
                </span>`;
            if (state.selected?.type === 'new') li.classList.add('active');
            li.onclick = () => selectNew();
        }
        list.appendChild(li);
    }
}

// ── Views ──────────────────────────────────────
function selectCharacter(char) {
    if (state.busy) return;
    state.selected = { type: 'char', char };
    renderSlots();

    $('view-create').classList.add('hidden');
    $('view-character').classList.remove('hidden');
    $('details').classList.remove('hidden');

    $('d-cid').textContent = `Slot ${char.cid ?? ''}`;
    $('d-name').textContent = `${char.firstname} ${char.lastname}`;
    $('d-dob').textContent = fmtDate(char.birthdate);
    $('d-gender').textContent = char.gender === 1 ? 'Female' : 'Male';
    $('d-nat').textContent = char.nationality || '—';
    $('d-job').textContent = char.grade ? `${char.job} · ${char.grade}` : char.job;
    $('d-cash').textContent = money(char.cash);
    $('d-bank').textContent = money(char.bank);
    $('d-phone').textContent = char.phone || '—';
    $('d-citizen').textContent = char.citizenid;
    $('btn-delete').classList.toggle('hidden', !state.allowDelete);

    post('preview', { citizenid: char.citizenid });
}

function selectNew() {
    if (state.busy) return;
    state.selected = { type: 'new' };
    renderSlots();

    $('view-character').classList.add('hidden');
    $('view-create').classList.remove('hidden');
    $('details').classList.remove('hidden');
    $('create-error').textContent = '';
    $('view-create').reset();

    post('preview', { gender: 0 });
}

function selectDefault() {
    if (state.characters.length) selectCharacter(state.characters[0]);
    else selectNew();
}

// ── Open / close ──────────────────────────────
function open(data) {
    state.characters = data.characters || [];
    state.maxSlots = data.maxSlots || 3;
    state.allowDelete = data.allowDelete !== false;
    state.busy = false;

    // nationalities: dropdown when limited (qbx_core limitNationalities), free text otherwise
    const sel = $('nat-select');
    const txt = $('nat-input');
    const limited = data.limitNationalities !== false;
    sel.classList.toggle('hidden', !limited); sel.disabled = !limited;
    txt.classList.toggle('hidden', limited);  txt.disabled = limited;
    sel.innerHTML = '<option value="" disabled selected>Select…</option>' +
        (data.nationalities || []).map((n) => `<option>${escapeHtml(n)}</option>`).join('');

    // date limits (qbx_core dateMin / dateMax)
    const dob = document.querySelector('input[name="birthdate"]');
    if (data.dateMin) dob.min = data.dateMin;
    if (data.dateMax) dob.max = data.dateMax;

    // name length
    if (data.nameMax) document.querySelectorAll('input[name="firstname"], input[name="lastname"]')
        .forEach((i) => { i.maxLength = data.nameMax; });

    $('app').classList.remove('hidden');
    selectDefault();
}

function close() {
    $('app').classList.add('hidden');
    $('modal').classList.add('hidden');
    state.selected = null;
}

window.addEventListener('message', (e) => {
    const { action, data } = e.data || {};
    if (action === 'open') open(data || {});
    if (action === 'close') close();
});

// ── Actions ──────────────────────────────────
$('btn-play').onclick = async () => {
    if (state.busy || state.selected?.type !== 'char') return;
    state.busy = true;
    $('btn-play').disabled = true;
    const res = await post('play', { citizenid: state.selected.char.citizenid });
    $('btn-play').disabled = false;
    if (!res?.ok) state.busy = false;
};

document.querySelectorAll('input[name="gender"]').forEach((r) => {
    r.addEventListener('change', () => post('preview', { gender: Number(r.value) }));
});

$('view-create').addEventListener('submit', async (e) => {
    e.preventDefault();
    if (state.busy) return;

    const f = new FormData(e.target);
    const payload = {
        firstname: (f.get('firstname') || '').trim(),
        lastname: (f.get('lastname') || '').trim(),
        birthdate: f.get('birthdate'),
        nationality: f.get('nationality'),
        gender: Number(f.get('gender')),
    };

    if (!payload.nationality) { $('create-error').textContent = 'Pick a nationality'; return; }

    state.busy = true;
    $('btn-create').disabled = true;
    $('create-error').textContent = '';
    const res = await post('create', payload);
    $('btn-create').disabled = false;

    if (!res?.ok) {
        state.busy = false;
        $('create-error').textContent = res?.error || 'Something went wrong';
    }
});

// Delete flow
let confirmWord = '';
$('btn-delete').onclick = () => {
    if (state.selected?.type !== 'char') return;
    const c = state.selected.char;
    confirmWord = c.firstname.toUpperCase();
    $('m-name').textContent = `${c.firstname} ${c.lastname}`;
    $('m-confirm-word').textContent = confirmWord;
    $('m-input').value = '';
    $('m-ok').disabled = true;
    $('modal').classList.remove('hidden');
    $('m-input').focus();
};
$('m-input').oninput = (e) => { $('m-ok').disabled = e.target.value.trim().toUpperCase() !== confirmWord; };
$('m-cancel').onclick = () => $('modal').classList.add('hidden');
$('m-ok').onclick = async () => {
    $('m-ok').disabled = true;
    const res = await post('delete', { citizenid: state.selected.char.citizenid });
    $('modal').classList.add('hidden');
    if (res?.ok) {
        state.characters = res.characters || [];
        state.selected = null;
        selectDefault();
    }
};

$('btn-disconnect').onclick = () => post('disconnect');

document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' && !$('modal').classList.contains('hidden')) $('modal').classList.add('hidden');
});

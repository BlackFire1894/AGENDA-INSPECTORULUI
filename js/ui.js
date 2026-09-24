// Componente de interfață reutilizabile (HTML ca șiruri).

const ICONS = {
  home: '<path d="M3 10.5 12 3l9 7.5V20a1 1 0 0 1-1 1h-5v-6h-6v6H4a1 1 0 0 1-1-1z"/>',
  building: '<path d="M4 21V5a2 2 0 0 1 2-2h8a2 2 0 0 1 2 2v16M16 9h2a2 2 0 0 1 2 2v10M2 21h20M8 7h4M8 11h4M8 15h4"/>',
  calendar: '<rect x="3" y="4.5" width="18" height="17" rx="2.5"/><path d="M3 9.5h18M8 2.5v4M16 2.5v4"/>',
  history: '<path d="M3.5 12a8.5 8.5 0 1 0 2.6-6.1L3.5 8.5"/><path d="M3.5 3.5v5h5M12 7.5V12l3 2"/>',
  settings: '<path d="M4 6h9M17 6h3M4 12h3M11 12h9M4 18h11M19 18h1"/><circle cx="15" cy="6" r="2"/><circle cx="9" cy="12" r="2"/><circle cx="17" cy="18" r="2"/>',
  plus: '<path d="M12 5v14M5 12h14"/>',
  search: '<circle cx="11" cy="11" r="7"/><path d="m20 20-3.5-3.5"/>',
  x: '<path d="M6 6l12 12M18 6 6 18"/>',
  check: '<path d="m5 12.5 4.5 4.5L19 7"/>',
  chevL: '<path d="m15 5-7 7 7 7"/>',
  chevR: '<path d="m9 5 7 7-7 7"/>',
  chevD: '<path d="m5 9 7 7 7-7"/>',
  phone: '<path d="M5 3h3.5l2 5-2.5 1.5a11 11 0 0 0 6.5 6.5l1.5-2.5 5 2V19a2 2 0 0 1-2 2A17 17 0 0 1 3 5a2 2 0 0 1 2-2z"/>',
  mail: '<rect x="3" y="5" width="18" height="14" rx="2"/><path d="m3 7 9 6 9-6"/>',
  trash: '<path d="M4 7h16M9 7V4h6v3M6 7l1 13a1 1 0 0 0 1 1h8a1 1 0 0 0 1-1l1-13M10 11v6M14 11v6"/>',
  download: '<path d="M12 3v12M7 10l5 5 5-5M4 20h16"/>',
  upload: '<path d="M12 16V4M7 9l5-5 5 5M4 20h16"/>',
  alert: '<path d="M10.3 3.9 2.4 18a2 2 0 0 0 1.7 3h15.8a2 2 0 0 0 1.7-3L13.7 3.9a2 2 0 0 0-3.4 0z"/><path d="M12 9.5v4M12 17h.01"/>',
  fine: '<rect x="2.5" y="6" width="19" height="12" rx="2"/><circle cx="12" cy="12" r="2.5"/><path d="M6 9.5v5M18 9.5v5"/>',
  clock: '<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>',
  doc: '<path d="M6 3h8l4 4v14H6z"/><path d="M14 3v4h4M9 12h6M9 16h6"/>',
  pv: '<path d="M6 3h8l4 4v14H6z"/><path d="M14 3v4h4"/><path d="m9 14 2 2 4-4"/>',
  flame: '<path d="M12 2.5c.8 3.6 5.5 5.6 5.5 11a5.5 5.5 0 0 1-11 0c0-2.8 1.6-4 2.1-6 .9 1.1 1.7 1.6 2.7 1.6-.1-2.6-.4-4.4.7-6.6z"/>',
  layers: '<path d="m12 3 9 5-9 5-9-5z"/><path d="m3 13 9 5 9-5"/>',
  shield: '<path d="M12 3 4.5 6v5.5c0 4.6 3.1 8.3 7.5 9.5 4.4-1.2 7.5-4.9 7.5-9.5V6z"/><path d="m9 12 2 2 4-4"/>',
  info: '<circle cx="12" cy="12" r="9"/><path d="M12 11v5M12 8h.01"/>',
  list: '<path d="M9 6h11M9 12h11M9 18h11M4.5 6h.01M4.5 12h.01M4.5 18h.01"/>',
  hourglass: '<path d="M6 3h12M6 21h12M7 3c0 5 10 6 10 9s-10 4-10 9M17 3c0 5-10 6-10 9s10 4 10 9"/>',
  more: '<circle cx="5" cy="12" r="1.3"/><circle cx="12" cy="12" r="1.3"/><circle cx="19" cy="12" r="1.3"/>',
  back: '<path d="M19 12H5M11 5l-7 7 7 7"/>',
  pin: '<path d="M12 21s-7-6.2-7-11.5a7 7 0 0 1 14 0C19 14.8 12 21 12 21z"/><circle cx="12" cy="9.5" r="2.5"/>',
  lock: '<rect x="4.5" y="10.5" width="15" height="10.5" rx="2"/><path d="M8 10.5V7.5a4 4 0 0 1 8 0v3M12 14.5v2.5"/>',
  up: '<path d="M12 19V5M5 12l7-7 7 7"/>',
  undo: '<path d="M9 14 4 9l5-5"/><path d="M4 9h10.5a5.5 5.5 0 0 1 0 11H11"/>',
  redo: '<path d="m15 14 5-5-5-5"/><path d="M20 9H9.5a5.5 5.5 0 0 0 0 11H13"/>',
  sun: '<circle cx="12" cy="12" r="4"/><path d="M12 2.5v2M12 19.5v2M4.6 4.6 6 6M18 18l1.4 1.4M2.5 12h2M19.5 12h2M4.6 19.4 6 18M18 6l1.4-1.4"/>',
  moon: '<path d="M20 14.5A8 8 0 0 1 9.5 4a8 8 0 1 0 10.5 10.5z"/>',
  contrast: '<circle cx="12" cy="12" r="9"/><path d="M12 3v18a9 9 0 0 0 0-18z" fill="currentColor"/>',
  locate: '<circle cx="12" cy="12" r="7"/><circle cx="12" cy="12" r="2.5"/><path d="M12 2v3M12 19v3M2 12h3M19 12h3"/>',
};

export function icon(name, cls = '') {
  return `<svg class="ic ${cls}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${ICONS[name] || ''}</svg>`;
}

export function esc(s) {
  return String(s ?? '').replace(/[&<>"']/g, (ch) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[ch]));
}

export function pill(level, text, ic) {
  return `<span class="pill pill-${level}">${ic ? icon(ic) : ''}${esc(text)}</span>`;
}

export function tipBadge(tip) {
  return tip === 'LOCALITATE'
    ? '<span class="badge badge-loc">Localitate</span>'
    : '<span class="badge badge-opec">OPEC / Instituție</span>';
}

export function empty(ic, title, text, action = '') {
  return `<div class="empty">${icon(ic)}<h3>${esc(title)}</h3><p>${esc(text)}</p>${action}</div>`;
}

let toastTimer;
// `action`: { label, fn } — ex. „Anulează” după o acțiune în bloc; mesajul stă mai mult pe ecran.
export function toast(msg, level = 'ok', action = null) {
  const el = document.getElementById('toast');
  el.className = `toast show toast-${level} ${action ? 'has-action' : ''}`;
  el.innerHTML = `${icon(level === 'ok' ? 'check' : 'alert')}<span>${esc(msg)}</span>${action ? `<button class="toast-btn">${esc(action.label)}</button>` : ''}`;
  if (action) {
    el.querySelector('.toast-btn').addEventListener('click', () => { el.className = 'toast'; action.fn(); }, { once: true });
  }
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => { el.className = 'toast'; }, action ? 7000 : 2600);
}

// Butonul de ajutor contextual „?”
export function helpBtn(key) {
  return `<button class="icon-btn big help-btn" data-act="help" data-key="${key}" aria-label="Ajutor pentru acest ecran" title="Ajutor">?</button>`;
}

// Fereastră modală. Returnează elementul corpului; închiderea prin closeModal().
export function openModal(html, { wide = false, onClose } = {}) {
  const root = document.getElementById('modal-root');
  root.innerHTML = `<div class="modal-backdrop" data-act="modal-close"></div>
    <div class="modal ${wide ? 'modal-wide' : ''}" role="dialog" aria-modal="true">${html}</div>`;
  root.classList.add('open');
  root._onClose = onClose;
  document.body.classList.add('modal-open');
  return root.querySelector('.modal');
}

export function closeModal() {
  const root = document.getElementById('modal-root');
  if (!root.classList.contains('open')) return;
  root.classList.remove('open');
  root.innerHTML = '';
  document.body.classList.remove('modal-open');
  const cb = root._onClose;
  root._onClose = null;
  if (cb) cb();
}

export function confirmDialog({ title, text, ok = 'Confirmă', danger = false }) {
  return new Promise((resolve) => {
    let done = false;
    const m = openModal(`
      <div class="modal-head"><h2>${esc(title)}</h2></div>
      <div class="modal-body"><p class="lead">${esc(text)}</p></div>
      <div class="modal-foot">
        <button class="btn btn-ghost btn-lg" data-r="0">Renunță</button>
        <button class="btn ${danger ? 'btn-danger' : 'btn-primary'} btn-lg" data-r="1">${esc(ok)}</button>
      </div>`, { onClose: () => { if (!done) resolve(false); } });
    m.querySelectorAll('[data-r]').forEach((b) => b.addEventListener('click', () => {
      done = true;
      resolve(b.dataset.r === '1');
      closeModal();
    }));
  });
}

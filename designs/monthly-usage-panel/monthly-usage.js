(() => {
  const key = 'codex-meter-monthly-design-v1';
  const defaults = { months: 6, visible: { activity: true, monthly: true, summary: true }, order: ['activity','monthly','summary'], dark: false };
  let saved;
  try { saved = JSON.parse(localStorage.getItem(key)); } catch (_) {}
  const state = structuredClone(defaults);
  if (saved) {
    if ([3,6,12].includes(saved.months)) state.months = saved.months;
    state.dark = saved.dark === true;
    for (const section of defaults.order) if (typeof saved.visible?.[section] === 'boolean') state.visible[section] = saved.visible[section];
    if (Array.isArray(saved.order) && saved.order.length === 3 && new Set(saved.order).size === 3 && saved.order.every(section => defaults.order.includes(section))) state.order = saved.order;
  }
  const save = () => { try { localStorage.setItem(key, JSON.stringify(state)); } catch (_) {} };
  function render() {
    document.documentElement.dataset.theme = state.dark ? 'dark' : 'light';
    document.getElementById('theme-toggle').textContent = state.dark ? '浅色预览' : '深色预览';
    document.getElementById('range-caption').textContent = `近 ${state.months} 个月`;
    document.querySelectorAll('#month-rows tr').forEach((row, index) => { row.hidden = index >= state.months; });
    document.querySelectorAll('[data-months]').forEach(button => {
      const active = Number(button.dataset.months) === state.months;
      button.classList.toggle('active', active);
      button.setAttribute('aria-pressed', String(active));
      button.disabled = !state.visible.monthly;
    });
    document.querySelectorAll('[data-visibility]').forEach(input => { input.checked = state.visible[input.dataset.visibility]; });
    document.getElementById('month-options').classList.toggle('disabled', !state.visible.monthly);
    for (const section of state.order) {
      const card = document.querySelector(`[data-section="${section}"]`);
      card.hidden = !state.visible[section];
      document.getElementById('card-stack').append(card);
      document.getElementById('display-list').append(document.querySelector(`[data-key="${section}"]`));
    }
    save();
  }
  document.querySelectorAll('[data-months]').forEach(button => button.addEventListener('click', () => { state.months = Number(button.dataset.months); render(); }));
  document.querySelectorAll('[data-visibility]').forEach(input => input.addEventListener('change', () => { state.visible[input.dataset.visibility] = input.checked; render(); }));
  document.getElementById('theme-toggle').addEventListener('click', () => { state.dark = !state.dark; render(); });
  document.getElementById('reset-preview').addEventListener('click', () => { Object.assign(state, structuredClone(defaults)); render(); });
  function showSettings() {
    const target = document.getElementById('settings-window');
    target.scrollIntoView({ behavior: matchMedia('(prefers-reduced-motion: reduce)').matches ? 'auto' : 'smooth', block: 'nearest' });
    target.classList.add('highlight-settings');
    document.querySelector('[data-months].active')?.focus({ preventScroll: true });
    setTimeout(() => target.classList.remove('highlight-settings'), 1000);
  }
  document.getElementById('open-settings').addEventListener('click', showSettings);
  document.getElementById('footer-settings').addEventListener('click', showSettings);
  document.querySelector('.refresh-button').addEventListener('click', () => {
    const now = new Date();
    document.getElementById('updated-at').textContent = `更新于 ${now.toLocaleTimeString('zh-CN', { hour: '2-digit', minute: '2-digit', hour12: false })}`;
  });
  let dragging = null;
  document.querySelectorAll('[data-key]').forEach(row => {
    row.querySelector('.drag-grip').addEventListener('keydown', event => {
      if (!['ArrowUp','ArrowDown'].includes(event.key)) return;
      event.preventDefault();
      const source = state.order.indexOf(row.dataset.key);
      const target = source + (event.key === 'ArrowUp' ? -1 : 1);
      if (target < 0 || target >= state.order.length) return;
      [state.order[source],state.order[target]] = [state.order[target],state.order[source]];
      render();
      row.querySelector('.drag-grip').focus({preventScroll:true});
    });
    row.addEventListener('dragstart', event => { dragging = row.dataset.key; event.dataTransfer.setData('text/plain', dragging); event.dataTransfer.effectAllowed = 'move'; row.classList.add('dragging'); });
    row.addEventListener('dragend', () => { dragging = null; row.classList.remove('dragging'); });
    row.addEventListener('dragover', event => { if (dragging && dragging !== row.dataset.key) { event.preventDefault(); event.dataTransfer.dropEffect = 'move'; } });
    row.addEventListener('drop', event => {
      event.preventDefault();
      const source = dragging;
      const target = row.dataset.key;
      if (!source || source === target) return;
      const sourceIndex = state.order.indexOf(source);
      const targetIndex = state.order.indexOf(target);
      state.order.splice(sourceIndex, 1);
      state.order.splice(targetIndex, 0, source);
      dragging = null;
      render();
    });
  });
  render();
})();

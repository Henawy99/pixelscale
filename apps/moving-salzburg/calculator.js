/* =================================================================
   Salzburg Umzugprofis – Enhanced Moving Cost Calculator
   calculator.js v2.0 – 7-step calculator with inventory & scheduling
   ================================================================= */

const CALC_CONFIG = {
  emailjs: {
    publicKey:          'YOUR_PUBLIC_KEY',
    serviceId:          'YOUR_SERVICE_ID',
    adminTemplateId:    'YOUR_ADMIN_TEMPLATE_ID',
    customerTemplateId: 'YOUR_CUSTOMER_TEMPLATE_ID'
  },
  adminPassword: 'admin2024',
  fallbackEmail: 'youssefelhenawy0@gmail.com'
};

/* ── DEFAULT PRICING ── */
const DEFAULT_PRICING = {
  base: 80, perKm: 1,
  rooms: { 0.5: 30, 1: 50, 2: 100, 3: 150, 4: 220, 5: 300 },
  floorNoElevator: 20,
  extras: { packaging: 50, assembly: 80, disposal: 70, storage: 30, cleaning: 90, insurance: 45 },
  heavyItems: { piano: 120, safe: 80, washer: 40, fridge: 35, aquarium: 60, gym: 50 },
  schedule: { weekend: 60, express: 100 }
};

function getPricing() {
  try {
    const s = localStorage.getItem('umzug_pricing');
    if (!s) return DEFAULT_PRICING;
    const saved = JSON.parse(s);
    // Merge with defaults for new fields
    return { ...DEFAULT_PRICING, ...saved, extras: { ...DEFAULT_PRICING.extras, ...saved.extras }, heavyItems: { ...DEFAULT_PRICING.heavyItems, ...(saved.heavyItems || {}) }, schedule: { ...DEFAULT_PRICING.schedule, ...(saved.schedule || {}) } };
  } catch { return DEFAULT_PRICING; }
}

/* ── CALCULATOR STATE ── */
const cs = {
  step: 1, totalSteps: 7,
  fromAddress: '', toAddress: '', distanceKm: null,
  rooms: 0, floor: 0, hasElevator: null,
  heavyItems: {},
  extras: {},
  timePreference: null,
  scheduleOptions: { weekend: false, express: false },
  contact: { name: '', email: '', phone: '', date: '', message: '' }
};

// Init heavy items
Object.keys(DEFAULT_PRICING.heavyItems).forEach(k => cs.heavyItems[k] = false);
Object.keys(DEFAULT_PRICING.extras).forEach(k => cs.extras[k] = false);

/* ── PRICE CALCULATION ── */
function calcPrice() {
  const p = getPricing();
  const base = p.base;
  const distCost = (parseFloat(cs.distanceKm) || 0) * p.perKm;
  const roomKey = cs.rooms || 0;
  const sizeCost = (p.rooms && p.rooms[roomKey]) ? p.rooms[roomKey] : 0;
  const floorCost = (!cs.hasElevator && cs.floor > 0) ? cs.floor * p.floorNoElevator : 0;

  let heavyCost = 0;
  Object.entries(cs.heavyItems).forEach(([k, v]) => {
    if (v && p.heavyItems[k]) heavyCost += p.heavyItems[k];
  });

  let extrasCost = 0;
  Object.entries(cs.extras).forEach(([k, v]) => {
    if (v && p.extras[k]) extrasCost += p.extras[k];
  });

  let scheduleCost = 0;
  if (cs.scheduleOptions.weekend) scheduleCost += p.schedule.weekend;
  if (cs.scheduleOptions.express) scheduleCost += p.schedule.express;

  const total = base + distCost + sizeCost + floorCost + heavyCost + extrasCost + scheduleCost;
  return {
    total, low: Math.round(total), high: Math.round(total * 1.18),
    breakdown: { base, distCost, sizeCost, floorCost, heavyCost, extrasCost, scheduleCost }
  };
}

/* ── UPDATE PRICE DISPLAY ── */
function updatePriceDisplay() {
  const { low, high, breakdown } = calcPrice();
  const set = (id, v) => { const e = document.getElementById(id); if (e) e.textContent = v; };
  set('calcPriceLow', low + '€');
  set('calcPriceHigh', high + '€');
  set('brkBase', breakdown.base + '€');
  set('brkDist', Math.round(breakdown.distCost) + '€');
  set('brkSize', Math.round(breakdown.sizeCost) + '€');
  set('brkHeavy', Math.round(breakdown.heavyCost) + '€');
  set('brkFloor', Math.round(breakdown.floorCost) + '€');
  set('brkExtras', Math.round(breakdown.extrasCost) + '€');
  set('brkSchedule', Math.round(breakdown.scheduleCost) + '€');
  set('calcPriceFinal', low + '€ – ' + high + '€');
  const disp = document.querySelector('.calc-price-widget');
  if (disp) { disp.classList.remove('price-pulse'); void disp.offsetWidth; disp.classList.add('price-pulse'); }
}

/* ── STEP NAVIGATION ── */
function goToStep(next) {
  if (next < 1 || next > cs.totalSteps) return;
  if (next > cs.step && !validateStep(cs.step)) return;
  updateStateFromDOM(cs.step);
  document.querySelectorAll('.calc-step').forEach(s => s.classList.remove('active'));
  const target = document.querySelector(`.calc-step[data-step="${next}"]`);
  if (target) target.classList.add('active');
  document.querySelectorAll('.calc-prog-step').forEach(ps => {
    const n = parseInt(ps.dataset.pstep);
    ps.classList.toggle('done', n < next);
    ps.classList.toggle('current', n === next);
    ps.classList.toggle('future', n > next);
  });
  cs.step = next;
  const prevBtn = document.getElementById('calcPrevBtn');
  const nextBtn = document.getElementById('calcNextBtn');
  const submitBtn = document.getElementById('calcSubmitBtn');
  if (prevBtn) prevBtn.style.display = next === 1 ? 'none' : '';
  if (nextBtn) nextBtn.style.display = next === cs.totalSteps ? 'none' : '';
  if (submitBtn) submitBtn.style.display = next === cs.totalSteps ? '' : 'none';
  updatePriceDisplay();
}

/* ── STEP VALIDATION ── */
function validateStep(step) {
  const warn = (msg) => { showCalcAlert(msg, 'warning'); return false; };
  if (step === 1) {
    if (!cs.fromAddress && !document.getElementById('calcFrom').value.trim())
      return warn('Bitte geben Sie die Auszugsadresse ein.');
    if (!cs.toAddress && !document.getElementById('calcTo').value.trim())
      return warn('Bitte geben Sie die Einzugsadresse ein.');
    if (cs.distanceKm === null) {
      const m = parseFloat(document.getElementById('calcManualKm').value);
      if (!m || m <= 0) return warn('Bitte Entfernung berechnen oder KM manuell eingeben.');
      cs.distanceKm = m;
    }
    return true;
  }
  if (step === 2) {
    if (cs.rooms === 0) return warn('Bitte wählen Sie die Wohnungsgröße.');
    return true;
  }
  // Step 3 (inventory) is optional
  if (step === 4) {
    if (cs.hasElevator === null) return warn('Bitte wählen Sie Aufzug Ja oder Nein.');
    return true;
  }
  // Steps 5 (extras) and 6 (date) are optional
  if (step === 7) {
    const n = document.getElementById('calcName').value.trim();
    const e = document.getElementById('calcEmail').value.trim();
    if (!n) return warn('Bitte geben Sie Ihren Namen ein.');
    if (!e || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(e)) return warn('Bitte geben Sie eine gültige E-Mail ein.');
    return true;
  }
  return true;
}

/* ── SYNC STATE FROM DOM ── */
function updateStateFromDOM(step) {
  if (step === 1) {
    cs.fromAddress = document.getElementById('calcFrom').value.trim();
    cs.toAddress = document.getElementById('calcTo').value.trim();
    const m = parseFloat(document.getElementById('calcManualKm').value);
    if (m > 0) cs.distanceKm = m;
  }
  if (step === 4) {
    cs.floor = parseInt(document.getElementById('calcFloor').value) || 0;
  }
  if (step === 6) {
    const dp = document.getElementById('calcDatePicker');
    if (dp) cs.contact.date = dp.value;
  }
  if (step === 7) {
    cs.contact.name = document.getElementById('calcName').value.trim();
    cs.contact.email = document.getElementById('calcEmail').value.trim();
    cs.contact.phone = document.getElementById('calcPhone').value.trim();
    cs.contact.message = document.getElementById('calcMessage').value.trim();
  }
}

/* ── DISTANCE CALCULATION ── */
async function calculateDistance() {
  const fromVal = document.getElementById('calcFrom').value.trim();
  const toVal = document.getElementById('calcTo').value.trim();
  if (!fromVal || !toVal) { showCalcAlert('Bitte beide Adressen eingeben.', 'warning'); return; }
  const btn = document.getElementById('calcDistBtn');
  const orig = btn.innerHTML;
  btn.innerHTML = '<i class="fas fa-spinner fa-spin"></i> Berechne...';
  btn.disabled = true;
  try {
    const [c1, c2] = await Promise.all([geocode(fromVal), geocode(toVal)]);
    const km = haversine(c1, c2);
    cs.distanceKm = parseFloat(km.toFixed(1));
    cs.fromAddress = fromVal;
    cs.toAddress = toVal;
    document.getElementById('calcManualKm').value = cs.distanceKm;
    document.getElementById('calcDistResult').textContent = `📍 Entfernung: ~${cs.distanceKm} km`;
    document.getElementById('calcDistResult').style.display = '';
    updatePriceDisplay();
    showCalcAlert(`Entfernung: ${cs.distanceKm} km`, 'success');
  } catch {
    showCalcAlert('Adresse nicht gefunden. Bitte KM manuell eingeben.', 'warning');
    document.getElementById('calcManualKm').focus();
  } finally {
    btn.innerHTML = orig;
    btn.disabled = false;
  }
}

async function geocode(address) {
  const q = encodeURIComponent(address + ', Österreich');
  const url = `https://nominatim.openstreetmap.org/search?q=${q}&format=json&limit=1&accept-language=de`;
  const r = await fetch(url, { headers: { 'User-Agent': 'SalzburgUmzugprofis/2.0' } });
  const d = await r.json();
  if (!d.length) throw new Error('not found');
  return { lat: parseFloat(d[0].lat), lon: parseFloat(d[0].lon) };
}

function haversine(a, b) {
  const R = 6371;
  const dLat = (b.lat - a.lat) * Math.PI / 180;
  const dLon = (b.lon - a.lon) * Math.PI / 180;
  const x = Math.sin(dLat / 2) ** 2 + Math.cos(a.lat * Math.PI / 180) * Math.cos(b.lat * Math.PI / 180) * Math.sin(dLon / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(x), Math.sqrt(1 - x));
}

/* ── ROOM SELECTION ── */
function selectRoom(n) {
  cs.rooms = n;
  document.querySelectorAll('.room-card').forEach(c => c.classList.remove('selected'));
  const sel = document.querySelector(`.room-card[data-rooms="${n}"]`);
  if (sel) sel.classList.add('selected');
  updatePriceDisplay();
}

/* ── ELEVATOR TOGGLE ── */
function setElevator(val) {
  cs.hasElevator = val;
  document.getElementById('elevYes').classList.toggle('selected', val === true);
  document.getElementById('elevNo').classList.toggle('selected', val === false);
  updatePriceDisplay();
}

/* ── EXTRAS TOGGLE ── */
function toggleExtra(key) {
  cs.extras[key] = !cs.extras[key];
  const card = document.querySelector(`.extra-card[data-extra="${key}"]`);
  if (card) card.classList.toggle('selected', cs.extras[key]);
  updatePriceDisplay();
}

/* ── HEAVY ITEMS TOGGLE ── */
function toggleHeavyItem(key) {
  cs.heavyItems[key] = !cs.heavyItems[key];
  const card = document.querySelector(`.inventory-item[data-item="${key}"]`);
  if (card) card.classList.toggle('selected', cs.heavyItems[key]);
  updatePriceDisplay();
}

/* ── TIME PREFERENCE ── */
function selectTime(val) {
  cs.timePreference = val;
  document.querySelectorAll('.time-card').forEach(c => c.classList.remove('selected'));
  const sel = document.querySelector(`.time-card[data-time="${val}"]`);
  if (sel) sel.classList.add('selected');
}

/* ── SCHEDULE OPTIONS ── */
function toggleSchedule(key) {
  cs.scheduleOptions[key] = !cs.scheduleOptions[key];
  const card = document.querySelector(`[data-schedule="${key}"]`);
  if (card) card.classList.toggle('selected', cs.scheduleOptions[key]);
  updatePriceDisplay();
}

/* ── FORM SUBMISSION ── */
async function submitCalculator(e) {
  if (e) e.preventDefault();
  updateStateFromDOM(7);
  if (!validateStep(7)) return;
  const btn = document.getElementById('calcSubmitBtn');
  btn.disabled = true;
  btn.innerHTML = '<i class="fas fa-spinner fa-spin"></i> Wird gesendet...';
  const { low, high } = calcPrice();
  const extrasLabel = Object.entries(cs.extras).filter(([, v]) => v)
    .map(([k]) => ({ packaging:'Verpackung', assembly:'Montage', disposal:'Entsorgung', storage:'Einlagerung', cleaning:'Endreinigung', insurance:'Versicherung+' }[k])).join(', ') || 'Keine';
  const heavyLabel = Object.entries(cs.heavyItems).filter(([, v]) => v)
    .map(([k]) => ({ piano:'Klavier', safe:'Tresor', washer:'Waschmaschine', fridge:'Kühlschrank', aquarium:'Aquarium', gym:'Fitnessgeräte' }[k])).join(', ') || 'Keine';
  const scheduleLabel = [cs.scheduleOptions.weekend ? 'Wochenende (+60€)' : '', cs.scheduleOptions.express ? 'Express (+100€)' : ''].filter(Boolean).join(', ') || 'Standard';
  const payload = {
    from_name: cs.contact.name, from_email: cs.contact.email,
    from_phone: cs.contact.phone || '–', move_date: cs.contact.date || '–',
    from_address: cs.fromAddress, to_address: cs.toAddress,
    distance_km: (cs.distanceKm || '?') + ' km',
    rooms: cs.rooms + ' Zimmer', floor: cs.floor + '. Etage',
    elevator: cs.hasElevator ? 'Ja' : 'Nein',
    heavy_items: heavyLabel, extras: extrasLabel,
    time_preference: cs.timePreference || 'Flexibel',
    schedule: scheduleLabel,
    total_price: low + '€ – ' + high + '€',
    message: cs.contact.message || '–',
    price_low: low + '€', price_high: high + '€',
    to_name: cs.contact.name, to_email: cs.contact.email
  };
  const emailJsReady = CALC_CONFIG.emailjs.publicKey !== 'YOUR_PUBLIC_KEY' && typeof emailjs !== 'undefined';
  try {
    if (emailJsReady) {
      emailjs.init(CALC_CONFIG.emailjs.publicKey);
      await emailjs.send(CALC_CONFIG.emailjs.serviceId, CALC_CONFIG.emailjs.adminTemplateId, payload);
      await emailjs.send(CALC_CONFIG.emailjs.serviceId, CALC_CONFIG.emailjs.customerTemplateId, payload);
    } else {
      const sub = encodeURIComponent('Umzugsanfrage – ' + cs.contact.name);
      const body = encodeURIComponent(
        `Name: ${payload.from_name}\nEmail: ${payload.from_email}\nTelefon: ${payload.from_phone}\n` +
        `Datum: ${payload.move_date}\nVon: ${payload.from_address}\nNach: ${payload.to_address}\n` +
        `Entfernung: ${payload.distance_km}\nZimmer: ${payload.rooms}\nEtage: ${payload.floor}\n` +
        `Aufzug: ${payload.elevator}\nSchwere Gegenstände: ${payload.heavy_items}\n` +
        `Extras: ${payload.extras}\nTermin: ${payload.schedule}\nZeit: ${payload.time_preference}\n` +
        `Preis: ${payload.total_price}\nNachricht: ${payload.message}`
      );
      window.location.href = `mailto:${CALC_CONFIG.fallbackEmail}?subject=${sub}&body=${body}`;
    }
    showSuccess();
  } catch (err) {
    console.error('Email error:', err);
    showCalcAlert('Fehler beim Senden. Bitte direkt an: ' + CALC_CONFIG.fallbackEmail, 'error');
    btn.disabled = false;
    btn.innerHTML = '<i class="fas fa-paper-plane"></i> Angebot anfordern';
  }
}

function showSuccess() {
  document.getElementById('calcFormInner').style.display = 'none';
  document.getElementById('calcSuccessMsg').style.display = '';
  document.getElementById('calcPrevBtn').style.display = 'none';
  document.getElementById('calcSubmitBtn').style.display = 'none';
  const { low, high } = calcPrice();
  document.getElementById('successPriceRange').textContent = low + '€ – ' + high + '€';
}

/* ── ALERT ── */
function showCalcAlert(msg, type = 'info') {
  let el = document.getElementById('calcAlert');
  if (!el) {
    el = document.createElement('div');
    el.id = 'calcAlert';
    document.querySelector('.calculator-wrapper').prepend(el);
  }
  el.className = 'calc-alert calc-alert-' + type;
  el.innerHTML = `<i class="fas fa-${type === 'success' ? 'check-circle' : type === 'warning' ? 'exclamation-triangle' : 'times-circle'}"></i> ${msg}`;
  el.style.display = '';
  clearTimeout(el._t);
  el._t = setTimeout(() => { el.style.display = 'none'; }, 4000);
}

/* ── ADDRESS AUTOCOMPLETE (Nominatim) ── */
const AC_CONFIG = { debounceMs: 300, minChars: 3, maxResults: 5 };
let _acTimers = {};

function initAutocomplete(inputId) {
  const input = document.getElementById(inputId);
  if (!input) return;

  // Wrap input in relative container if not already
  if (!input.parentElement.classList.contains('ac-wrapper')) {
    const wrapper = document.createElement('div');
    wrapper.className = 'ac-wrapper';
    input.parentElement.insertBefore(wrapper, input);
    wrapper.appendChild(input);
  }

  // Create dropdown
  let dropdown = input.parentElement.querySelector('.ac-dropdown');
  if (!dropdown) {
    dropdown = document.createElement('div');
    dropdown.className = 'ac-dropdown';
    dropdown.style.display = 'none';
    input.parentElement.appendChild(dropdown);
  }

  let activeIdx = -1;

  input.addEventListener('input', () => {
    const q = input.value.trim();
    clearTimeout(_acTimers[inputId]);
    if (q.length < AC_CONFIG.minChars) { hideDropdown(dropdown); return; }
    // Show loading
    dropdown.innerHTML = '<div class="ac-loading"><i class="fas fa-spinner fa-spin"></i> Suche...</div>';
    dropdown.style.display = '';
    activeIdx = -1;
    _acTimers[inputId] = setTimeout(() => fetchSuggestions(q, dropdown, input), AC_CONFIG.debounceMs);
  });

  input.addEventListener('keydown', (e) => {
    const items = dropdown.querySelectorAll('.ac-item');
    if (!items.length || dropdown.style.display === 'none') return;
    if (e.key === 'ArrowDown') { e.preventDefault(); activeIdx = Math.min(activeIdx + 1, items.length - 1); highlightItem(items, activeIdx); }
    else if (e.key === 'ArrowUp') { e.preventDefault(); activeIdx = Math.max(activeIdx - 1, 0); highlightItem(items, activeIdx); }
    else if (e.key === 'Enter' && activeIdx >= 0) { e.preventDefault(); items[activeIdx].click(); }
    else if (e.key === 'Escape') { hideDropdown(dropdown); }
  });

  input.addEventListener('blur', () => { setTimeout(() => hideDropdown(dropdown), 200); });
  input.addEventListener('focus', () => {
    if (input.value.trim().length >= AC_CONFIG.minChars && dropdown.children.length > 0 && dropdown.querySelector('.ac-item')) {
      dropdown.style.display = '';
    }
  });
}

async function fetchSuggestions(query, dropdown, input) {
  try {
    const q = encodeURIComponent(query + ', Österreich');
    const url = `https://nominatim.openstreetmap.org/search?q=${q}&format=json&limit=${AC_CONFIG.maxResults}&accept-language=de&countrycodes=at&addressdetails=1`;
    const r = await fetch(url, { headers: { 'User-Agent': 'SalzburgUmzugprofis/2.0' } });
    if (!r.ok) throw new Error('Network error');
    const data = await r.json();
    renderSuggestions(data, dropdown, input);
  } catch (err) {
    dropdown.innerHTML = '<div class="ac-empty"><i class="fas fa-exclamation-circle"></i> Fehler beim Laden</div>';
  }
}

function renderSuggestions(results, dropdown, input) {
  if (!results.length) {
    dropdown.innerHTML = '<div class="ac-empty"><i class="fas fa-map-marker-alt"></i> Keine Ergebnisse gefunden</div>';
    return;
  }
  dropdown.innerHTML = '';
  results.forEach((r, i) => {
    const item = document.createElement('div');
    item.className = 'ac-item';
    item.dataset.lat = r.lat;
    item.dataset.lon = r.lon;
    // Build nice display name
    const addr = r.address || {};
    const main = r.display_name.split(',')[0];
    const sub = [addr.city || addr.town || addr.village || '', addr.state || ''].filter(Boolean).join(', ');
    item.innerHTML = `<i class="fas fa-map-marker-alt ac-icon"></i><div class="ac-text"><span class="ac-main">${main}</span><span class="ac-sub">${sub || r.display_name.split(',').slice(1, 3).join(',')}</span></div>`;
    item.addEventListener('click', () => {
      input.value = r.display_name;
      hideDropdown(dropdown);
      input.dispatchEvent(new Event('input', { bubbles: true }));
    });
    dropdown.appendChild(item);
  });
}

function highlightItem(items, idx) {
  items.forEach((el, i) => el.classList.toggle('ac-active', i === idx));
  if (items[idx]) items[idx].scrollIntoView({ block: 'nearest' });
}

function hideDropdown(dropdown) { dropdown.style.display = 'none'; }

/* ── INIT ── */
function initCalculator() {
  const distBtn = document.getElementById('calcDistBtn');
  if (distBtn) distBtn.addEventListener('click', calculateDistance);
  const manKm = document.getElementById('calcManualKm');
  if (manKm) manKm.addEventListener('input', () => { cs.distanceKm = parseFloat(manKm.value) || null; updatePriceDisplay(); });
  const floorIn = document.getElementById('calcFloor');
  if (floorIn) floorIn.addEventListener('input', () => { cs.floor = parseInt(floorIn.value) || 0; updatePriceDisplay(); });
  const prevBtn = document.getElementById('calcPrevBtn');
  const nextBtn = document.getElementById('calcNextBtn');
  const submitBtn = document.getElementById('calcSubmitBtn');
  if (prevBtn) prevBtn.addEventListener('click', () => goToStep(cs.step - 1));
  if (nextBtn) nextBtn.addEventListener('click', () => goToStep(cs.step + 1));
  if (submitBtn) submitBtn.addEventListener('click', submitCalculator);
  // Room cards
  document.querySelectorAll('.room-card').forEach(c => {
    c.addEventListener('click', () => selectRoom(parseFloat(c.dataset.rooms)));
  });
  // Elevator
  const evY = document.getElementById('elevYes');
  const evN = document.getElementById('elevNo');
  if (evY) evY.addEventListener('click', () => setElevator(true));
  if (evN) evN.addEventListener('click', () => setElevator(false));
  // Extras
  document.querySelectorAll('.extra-card[data-extra]').forEach(c => {
    c.addEventListener('click', () => toggleExtra(c.dataset.extra));
  });
  // Heavy items
  document.querySelectorAll('.inventory-item').forEach(c => {
    c.addEventListener('click', () => toggleHeavyItem(c.dataset.item));
  });
  // Time cards
  document.querySelectorAll('.time-card').forEach(c => {
    c.addEventListener('click', () => selectTime(c.dataset.time));
  });
  // Schedule options
  document.querySelectorAll('[data-schedule]').forEach(c => {
    c.addEventListener('click', () => toggleSchedule(c.dataset.schedule));
  });
  // Contact live sync
  ['calcName','calcEmail','calcPhone','calcMessage'].forEach(fid => {
    const el = document.getElementById(fid);
    if (el) el.addEventListener('input', () => updateStateFromDOM(7));
  });
  // Load EmailJS
  if (CALC_CONFIG.emailjs.publicKey !== 'YOUR_PUBLIC_KEY') {
    const s = document.createElement('script');
    s.src = 'https://cdn.jsdelivr.net/npm/@emailjs/browser@3/dist/email.min.js';
    document.head.appendChild(s);
  }

  // ── Address Autocomplete ──
  initAutocomplete('calcFrom');
  initAutocomplete('calcTo');

  updatePriceDisplay();
  goToStep(1);
}

document.addEventListener('DOMContentLoaded', initCalculator);

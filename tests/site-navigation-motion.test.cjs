'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const source = fs.readFileSync(path.join(__dirname, '..', 'assets', 'site.js'), 'utf8');

function runNavigation(reducedMotion) {
  const listeners = new Map();
  const timers = [];
  const location = {
    pathname: '/compatibility.html',
    search: '',
    hash: '',
    origin: 'https://example.test',
    href: 'https://example.test/compatibility.html',
  };
  const bodyClasses = {
    add() {},
    toggle() {},
    contains() { return false; },
  };
  const document = {
    body: { classList: bodyClasses },
    documentElement: { scrollHeight: 0 },
    querySelector(selector) { return selector === '.nav a' ? [] : null; },
    querySelectorAll() { return []; },
    addEventListener(name, callback) {
      const current = listeners.get(name) || [];
      current.push(callback);
      listeners.set(name, current);
    },
  };
  const window = {
    addEventListener() {},
    matchMedia(query) {
      assert.equal(query, '(prefers-reduced-motion: reduce)');
      return { matches: reducedMotion };
    },
  };
  const link = {
    target: '',
    origin: location.origin,
    hash: '',
    getAttribute(name) { return name === 'href' ? '/profiles.html' : null; },
  };
  const target = {
    classList: { contains() { return false; } },
    closest(selector) { return selector === 'a' ? link : null; },
  };
  const context = {
    document,
    window,
    location,
    setTimeout(callback, delay) {
      timers.push({ callback, delay });
      return timers.length;
    },
    clearTimeout() {},
  };

  vm.runInNewContext(source, context, { filename: 'assets/site.js' });
  const clickHandlers = listeners.get('click') || [];
  let prevented = false;
  const event = {
    target,
    metaKey: false,
    ctrlKey: false,
    shiftKey: false,
    altKey: false,
    preventDefault() { prevented = true; },
  };
  for (const handler of clickHandlers) handler(event);
  return { location, timers, prevented };
}

test('reduced-motion navigation skips the exit timer', () => {
  const result = runNavigation(true);
  assert.equal(result.prevented, true);
  assert.equal(result.location.href, '/profiles.html');
  assert.equal(result.timers.length, 0);
});

test('normal navigation retains the short exit transition', () => {
  const result = runNavigation(false);
  assert.equal(result.prevented, true);
  assert.equal(result.location.href, 'https://example.test/compatibility.html');
  assert.equal(result.timers.length, 1);
  assert.equal(result.timers[0].delay, 150);
  result.timers[0].callback();
  assert.equal(result.location.href, '/profiles.html');
});


function runOverlayFocusTrap(active, shiftKey) {
  const listeners = new Map();
  let focused = '';
  const first = { hidden: false, focus() { focused = 'first'; } };
  const last = { hidden: false, focus() { focused = 'last'; } };
  const dialog = {
    querySelectorAll() { return [first, last]; },
    contains(node) { return node === first || node === last; },
    focus() { focused = 'dialog'; },
  };
  const overlay = {
    getAttribute(name) { return name === 'aria-hidden' ? 'false' : null; },
    querySelector(selector) {
      return selector === '[role="dialog"][aria-modal="true"]' ? dialog : null;
    },
  };
  const document = {
    body: {
      classList: {
        add() {},
        toggle() {},
        contains() { return false; },
      },
    },
    documentElement: { scrollHeight: 0 },
    activeElement: active === 'first' ? first : last,
    querySelector() { return null; },
    querySelectorAll(selector) {
      return selector === '.detail-overlay.show' ? [overlay] : [];
    },
    addEventListener(name, callback) {
      const current = listeners.get(name) || [];
      current.push(callback);
      listeners.set(name, current);
    },
  };
  const window = {
    addEventListener() {},
    matchMedia() { return { matches: false }; },
  };
  const context = {
    document,
    window,
    location: {
      pathname: '/compatibility.html',
      origin: 'https://example.test',
      href: 'https://example.test/compatibility.html',
    },
    setTimeout() { return 1; },
    clearTimeout() {},
  };

  vm.runInNewContext(source, context, { filename: 'assets/site.js' });
  let prevented = false;
  const event = {
    key: 'Tab',
    shiftKey,
    preventDefault() { prevented = true; },
  };
  for (const handler of listeners.get('keydown') || []) handler(event);
  return { focused, prevented };
}

test('open modal overlays trap Tab focus in both directions', () => {
  const forward = runOverlayFocusTrap('last', false);
  assert.equal(forward.prevented, true);
  assert.equal(forward.focused, 'first');

  const reverse = runOverlayFocusTrap('first', true);
  assert.equal(reverse.prevented, true);
  assert.equal(reverse.focused, 'last');
});

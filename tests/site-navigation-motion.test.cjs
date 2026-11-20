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
    querySelector() { return null; },
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

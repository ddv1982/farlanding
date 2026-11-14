const { test, expect } = require('@playwright/test');
const fs = require('node:fs/promises');
const { captureAudio } = require('./audio-capture.cjs');

async function state(page) { return page.evaluate(() => window.farlanding?.diagnostics); }
async function boot(page, url) {
  await page.goto(url);
  await page.getByRole('button', { name: 'Play Farlanding' }).click();
  await expect.poll(() => page.evaluate(() => window.farlanding?.ready), { timeout: 90000 }).toBe(true);
}
async function button(page, label) {
  await expect.poll(async () => (await state(page))?.buttons.some(b => b.text.startsWith(label))).toBe(true);
  const target = (await state(page)).buttons.find(b => b.text.startsWith(label));
  await page.mouse.click(...target.pixel, { delay: 80 });
}
async function entity(page, collection, predicate) {
  const target = (await state(page))[collection].find(predicate);
  expect(target, `${collection} target`).toBeTruthy();
  await page.mouse.click(...target.pixel, { delay: 80 });
  return target;
}

test.beforeEach(async ({ page }, info) => {
  const logs = [];
  page.on('console', entry => logs.push({ type: entry.type(), text: entry.text() }));
  page.on('pageerror', error => logs.push({ type: 'pageerror', text: String(error) }));
  page.on('requestfailed', request => logs.push({ type: 'network', url: request.url(), failure: request.failure() }));
  info._logs = logs;
});
test.afterEach(async ({ page }, info) => {
  await fs.writeFile(info.outputPath('browser-log.json'), JSON.stringify(info._logs, null, 2));
  if (!page.isClosed()) {
    await fs.writeFile(info.outputPath('storage-checks.json'), JSON.stringify(await page.evaluate(async () => {
      const checks = [];
      for (const args of window.saveChecks || []) {
        const content = await storedFile(args[0]);
        const bytes = content && new Uint8Array(await crypto.subtle.digest('SHA-256', content));
        checks.push({ args, actual: bytes && Array.from(bytes, b => b.toString(16).padStart(2, '0')).join('') });
      }
      return checks;
    }), null, 2));
    await fs.writeFile(info.outputPath('state.json'), JSON.stringify(await page.evaluate(() => window.farlanding), null, 2));
  }
  expect(info._logs.filter(entry => ['error', 'pageerror', 'network'].includes(entry.type))).toEqual([]);
});

test('release starts on WebGL2 and uses real menu input', async ({ page }, info) => {
  const response = await page.request.get('http://127.0.0.1:8070/index.wasm');
  expect(response.headers()['content-type']).toContain('application/wasm');
  expect(response.headers()['cross-origin-opener-policy']).toBe('same-origin');
  expect(response.headers()['cross-origin-embedder-policy']).toBe('require-corp');
  const started = Date.now();
  await boot(page, 'http://127.0.0.1:8070');
  expect(await page.evaluate(() => crossOriginIsolated)).toBe(true);
  expect(await page.evaluate(() => window.farlanding.diagnostics)).toBeUndefined();
  const renderer = await page.evaluate(() => {
    const gl = document.querySelector('canvas').getContext('webgl2');
    return gl && gl.getParameter(gl.RENDERER);
  });
  expect(renderer).toBeTruthy();
  await info.attach('runtime', { body: JSON.stringify({ renderer, startupMs: Date.now() - started }), contentType: 'application/json' });
  await page.screenshot({ path: info.outputPath('release-title.png') });
  await page.mouse.click(630, 388);
  await page.screenshot({ path: info.outputPath('release-menu.png') });
  await page.mouse.click(600, 285, { delay: 80 });
  const landing = page.waitForEvent('console', { predicate: entry => entry.text().includes('kessel_proving: 18 resource nodes and the bases placed'), timeout: 90000 });
  await page.mouse.click(850, 522, { delay: 80 });
  await landing;
  await page.mouse.click(580, 385, { delay: 80 });
  await page.screenshot({ path: info.outputPath('release-landing.png') });
});

test('worker orders construction production and saves survive reload', async ({ page }, info) => {
  // Three simulation waits plus two launches need a bounded software-rendering budget.
  test.setTimeout(480000);
  await page.addInitScript(captureAudio);
  await boot(page, 'http://127.0.0.1:8071/?mission=conquest');
  await expect.poll(async () => (await state(page))?.mission).toBe('conquest');
  expect((await state(page)).music_source_layers).toBeGreaterThan(0);
  expect((await state(page)).music_layers).toBe((await state(page)).music_source_layers);
  expect((await state(page)).music_volumes).toBe((await state(page)).music_source_layers);
  expect((await state(page)).audio_playback).toBe('stream');
  expect((await state(page)).quality).toBe('low');
  expect((await state(page)).render_scale).toBe(0.5);
  await page.evaluate(() => {
    const original = confirmFile;
    window.saveChecks = [];
    window.confirmFile = (...args) => { window.saveChecks.push(args); return original(...args); };
  });
  await button(page, 'GOT IT');
  const worker = await entity(page, 'units', u => u.kind === 'concord_fabricator');
  await expect.poll(async () => (await state(page)).selected).toContain(worker.id);
  await expect.poll(() => page.evaluate(() => window.audioCapture.rms)).toBeGreaterThan(0.0001);
  await button(page, 'Reactor');
  await expect.poll(async () => (await state(page)).placing).toBe(true);
  await page.mouse.move(...(await state(page)).ground[0]);
  await expect.poll(async () => (await state(page)).placement_reason).toBe('');
  await page.mouse.click(...(await state(page)).ground[0], { delay: 80 });
  await expect.poll(async () => (await state(page)).buildings.some(b => b.kind === 'concord_reactor')).toBe(true);
  await expect.poll(async () => (await state(page)).buildings.some(b => b.kind === 'concord_reactor' && !b.constructing), { timeout: 90000 }).toBe(true);
  await page.keyboard.press('Escape');
  await button(page, 'RESUME');
  const hauler = (await state(page)).units.find(u => u.kind === 'concord_hauler');
  expect(hauler, 'Hauler target').toBeTruthy();
  // Box-select the base crew across the Hauler's whole route, rather than an
  // ageing point sample. The rectangle stays clear of tutorial and command UI.
  await page.mouse.move(1020, 510);
  await page.mouse.down();
  await page.mouse.move(310, 205, { steps: 8 });
  await page.mouse.up();
  await expect.poll(async () => (await state(page)).selected).toContain(hauler.id);
  const deposit = (await state(page)).deposits.find(d => d.remaining > 0 && d.pixel[0] > 850 && d.pixel[0] < 1100 && d.pixel[1] > 200);
  await page.mouse.click(...deposit.pixel);
  await expect.poll(async () => (await state(page)).deposits.find(d => d.id === deposit.id).remaining, { timeout: 90000 }).toBeLessThan(deposit.remaining);
  await entity(page, 'buildings', b => b.kind === 'concord_lander');
  await button(page, 'Fabricator');
  const units = (await state(page)).units.filter(u => u.faction === 0).length;
  await expect.poll(async () => (await state(page)).units.filter(u => u.faction === 0).length, { timeout: 90000 }).toBeGreaterThan(units);
  await page.keyboard.press('k');
  await expect.poll(async () => (await state(page)).quicksave).not.toBe('');
  await expect.poll(async () => (await state(page)).notice).toBe('Saved to Quicksave.');
  await page.keyboard.press('Escape');
  await expect.poll(async () => (await state(page)).paused).toBe(true);
  const capture = await page.evaluate(async () => {
    const recorder = window.audioCapture.recorder;
    await new Promise(resolve => { recorder.onstop = resolve; recorder.stop(); });
    return Array.from(new Uint8Array(await new Blob(window.audioCapture.chunks).arrayBuffer()));
  });
  await info.attach('actual-browser-audio.webm', { body: Buffer.from(capture), contentType: 'audio/webm' });
  const saved = (await state(page)).quicksave;
  await page.screenshot({ path: info.outputPath('saved-landing.png') });
  await page.reload();
  await page.getByRole('button', { name: 'Play Farlanding' }).click();
  await expect.poll(async () => (await state(page))?.quicksave, { timeout: 90000 }).toBe(saved);
  await page.keyboard.press('l');
  await expect.poll(async () => (await state(page)).notice).toContain('Loaded Quicksave');
  await expect.poll(async () => (await state(page)).buildings.some(b => b.kind === 'concord_reactor' && !b.constructing)).toBe(true);
  await expect.poll(async () => (await state(page)).units.filter(u => u.faction === 0).length).toBeGreaterThan(units);
  await expect.poll(async () => (await state(page)).units.some(u => u.kind === 'concord_hauler' && u.id === hauler.id)).toBe(true);
  await page.keyboard.press('Escape');
  await button(page, 'QUIT TO MISSIONS');
  await button(page, 'BACK');
  await expect.poll(async () => (await state(page)).screen).toBe('title');
});

test('denied storage shows an honest warning', async ({ page }) => {
  await page.addInitScript(() => Object.defineProperty(window, 'indexedDB', { get() { throw new DOMException('Denied', 'SecurityError'); } }));
  await page.goto('http://127.0.0.1:8070');
  await page.getByRole('button', { name: 'Play Farlanding' }).click();
  await expect(page.getByRole('alert')).toContainText('storage is unavailable');
  await expect.poll(() => page.evaluate(() => window.farlanding.ready), { timeout: 90000 }).toBe(true);
});

test('combat causes damage after a real attack order', async ({ page }) => {
  await boot(page, 'http://127.0.0.1:8071/?mission=conquest&encounter');
  await button(page, 'GOT IT');
  await entity(page, 'units', u => u.kind === 'concord_ranger');
  const enemy = (await state(page)).units.find(u => u.kind === 'combine_skitter' && u.position[0] < 0);
  expect(enemy).toBeTruthy();
  await page.mouse.click(...enemy.pixel, { delay: 80 });
  await expect.poll(async () => {
    const current = (await state(page)).units.find(u => u.id === enemy.id);
    return !current || current.health < enemy.health;
  }).toBe(true);
});

if (process.env.WEB_BROAD) {
  for (const mission of ['conquest', 'survey', 'infiltration', 'thalassa_recovery', 'emberfall_conquest', 'emberfall_holdout', 'verdance_conquest', 'verdance_infiltration', 'hollow_power', 'hollow_finale']) {
    test(`mission renders and advances: ${mission}`, async ({ page }, info) => {
      await boot(page, `http://127.0.0.1:8071/?mission=${mission}`);
      await expect.poll(async () => (await state(page))?.tick, { timeout: 90000 }).toBeGreaterThan(20);
      expect((await state(page)).units.length).toBeGreaterThan(0);
      await page.screenshot({ path: info.outputPath(`${mission}.png`) });
    });
  }
}

const { play } = require('./launch.cjs');
const { test, expect } = require('@playwright/test');

test('missing assets produce an actionable launch failure', async ({ page }) => {
  await page.route('**/index.pck', route => route.abort('failed'));
  await page.goto('http://127.0.0.1:8070');
  await play(page);
  await expect.poll(() => page.evaluate(() => window.farlanding.errors.length), { timeout: 90000 }).toBeGreaterThan(0);
  await expect(page.locator('#message')).not.toHaveText('Loading expedition…');
  expect(await page.evaluate(() => window.farlanding.ready)).toBe(false);
});

test('a missing ready signal cannot pass the runtime gate', async ({ page }) => {
  await page.addInitScript(() => {
    let state;
    Object.defineProperty(window, 'farlanding', {
      get: () => state,
      set(value) {
        state = value;
        Object.defineProperty(state, 'ready', { get: () => false, set() {} });
      },
    });
  });
  await page.goto('http://127.0.0.1:8070');
  await play(page);
  await expect(page.locator('#launch')).toHaveCount(0, { timeout: 90000 });
  await expect(page.waitForFunction(() => window.farlanding.ready, null, { timeout: 500 })).rejects.toThrow();
});

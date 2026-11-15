const { play } = require('./launch.cjs');
const { test, expect } = require('@playwright/test');
const state = page => page.evaluate(() => window.farlanding?.diagnostics);
async function click(page, prefix) {
  await expect.poll(async () => (await state(page))?.buttons.some(b => b.text.startsWith(prefix))).toBe(true);
  const target = (await state(page)).buttons.find(b => b.text.startsWith(prefix));
  await page.mouse.click(...target.pixel, { delay: 80 });
}

test('title Load game returns with Back or Escape and restores a saved landing', async ({ page }, info) => {
  await page.goto('http://127.0.0.1:8071/?mission=conquest');
  await play(page);
  await expect.poll(async () => (await state(page))?.tick, { timeout: 90000 }).toBeGreaterThan(0);
  await click(page, 'GOT IT');
  await page.keyboard.press('k');
  await expect.poll(async () => (await state(page)).notice).toBe('Saved to Quicksave.');
  const saved = (await state(page)).quicksave;
  await page.keyboard.press('Escape');
  await click(page, 'QUIT TO MISSIONS');
  await click(page, 'BACK');
  await expect.poll(async () => (await state(page)).screen).toBe('title');
  await click(page, 'LOAD GAME');
  await expect.poll(async () => (await state(page)).buttons.some(b => b.text.startsWith('QUICKSAVE'))).toBe(true);
  await page.screenshot({ path: info.outputPath('title-load-game.png') });
  await click(page, 'BACK');
  await expect.poll(async () => (await state(page)).buttons.some(b => b.text.startsWith('QUICKSAVE'))).toBe(false);
  await click(page, 'LOAD GAME');
  await page.keyboard.press('Escape');
  await expect.poll(async () => (await state(page)).buttons.some(b => b.text.startsWith('QUICKSAVE'))).toBe(false);
  await click(page, 'LOAD GAME');
  await click(page, 'QUICKSAVE');
  await expect.poll(async () => (await state(page)).notice).toContain('Loaded Quicksave');
  await expect.poll(async () => (await state(page)).tick).toBeGreaterThan(0);
  expect((await state(page)).quicksave).toBe(saved);
  expect((await state(page)).paused).toBe(false);
  expect((await state(page)).buttons.some(b => b.text === 'LOAD GAME')).toBe(false);
  expect(await page.evaluate(() => window.farlanding.errors)).toEqual([]);
});

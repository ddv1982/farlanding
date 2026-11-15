const { play } = require('./launch.cjs');
const { test, expect } = require('@playwright/test');
const state = page => page.evaluate(() => window.farlanding?.diagnostics);
async function click(page, prefix) {
  await expect.poll(async () => (await state(page))?.buttons.some(b => b.text.startsWith(prefix))).toBe(true);
  const button = (await state(page)).buttons.find(b => b.text.startsWith(prefix));
  await page.mouse.click(...button.pixel, { delay: 80 });
}

test('owned building sale previews refunds confirms and stays removed after saving', async ({ page }, info) => {
  test.setTimeout(240000);
  await page.goto('http://127.0.0.1:8071/?mission=conquest'); await play(page);
  await expect.poll(async () => (await state(page))?.tick, { timeout: 90000 }).toBeGreaterThan(0);
  await click(page, 'GOT IT');
  const worker = (await state(page)).units.find(u => u.kind === 'concord_fabricator');
  await page.mouse.click(...worker.pixel, { delay: 80 });
  await click(page, 'Reactor');
  await expect.poll(async () => (await state(page)).placing).toBe(true);
  await page.mouse.move(...(await state(page)).ground[0]);
  await expect.poll(async () => (await state(page)).placement_reason).toBe('');
  await page.mouse.click(...(await state(page)).ground[0], { delay: 80 });
  await expect.poll(async () => (await state(page)).buildings.some(b => b.kind === 'concord_reactor' && !b.constructing), { timeout: 90000 }).toBe(true);
  const reactor = (await state(page)).buildings.find(b => b.kind === 'concord_reactor');
  await page.mouse.click(...reactor.pixel, { delay: 80 });
  await click(page, 'SELL');
  await expect.poll(async () => (await state(page)).buttons.some(b => b.text.startsWith('Confirm sell') && b.text.includes('+75 Alloy'))).toBe(true);
  await page.screenshot({ path: info.outputPath('sell-confirmation.png') });
  await click(page, 'Cancel');
  expect((await state(page)).buildings.some(b => b.id === reactor.id)).toBe(true);
  await click(page, 'SELL');
  const before = (await state(page)).stockpile;
  await click(page, 'Confirm sell');
  await expect.poll(async () => (await state(page)).buildings.some(b => b.id === reactor.id)).toBe(false);
  expect((await state(page)).stockpile.alloy).toBeGreaterThanOrEqual(before.alloy + 75);
  expect((await state(page)).stockpile.power_produced).toBe(before.power_produced - 15);
  await page.keyboard.press('k');
  await expect.poll(async () => (await state(page)).notice).toBe('Saved to Quicksave.');
  await page.keyboard.press('l');
  await expect.poll(async () => (await state(page)).notice).toContain('Loaded Quicksave');
  expect((await state(page)).buildings.some(b => b.id === reactor.id)).toBe(false);
  const lander = (await state(page)).buildings.find(b => b.kind === 'concord_lander');
  await page.mouse.click(...lander.pixel, { delay: 80 });
  await expect.poll(async () => (await state(page)).buttons.some(b => b.text.startsWith('Fabricator'))).toBe(true);
  expect((await state(page)).buttons.some(b => b.text.startsWith('SELL'))).toBe(false);
  expect(await page.evaluate(() => window.farlanding.errors)).toEqual([]);
});

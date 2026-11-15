const { play } = require('./launch.cjs');
const { test, expect } = require('@playwright/test');
async function state(page) { return page.evaluate(() => window.farlanding?.diagnostics); }
async function button(page, text) {
  await expect.poll(async () => (await state(page))?.buttons.some(item => item.text.startsWith(text))).toBe(true);
  const target = (await state(page)).buttons.find(item => item.text.startsWith(text));
  await page.mouse.click(...target.pixel, { delay: 80 });
}

if (process.env.WEB_CAMPAIGN || process.env.WEB_BROAD) {
test('campaign launch and Continue preserve the landing across reload', async ({ page }) => {
  await page.goto('http://127.0.0.1:8071');
  await play(page);
  await expect.poll(async () => (await state(page))?.screen, { timeout: 90000 }).toBe('title');
  await button(page, 'NEW CAMPAIGN');
  await button(page, 'START');
  await expect.poll(async () => (await state(page)).screen).toBe('star_map');
  await expect.poll(async () => (await state(page)).buttons.some(item => item.name === 'kessel_proving')).toBe(true);
  const landing = (await state(page)).buttons.find(item => item.name === 'kessel_proving');
  await page.mouse.click(...landing.pixel, { delay: 80 });
  await button(page, 'LAUNCH');
  await button(page, 'START LANDING');
  await expect.poll(async () => (await state(page)).tick).toBeGreaterThan(0);
  expect((await state(page)).campaign_active).toBe(true);
  await page.keyboard.press('k');
  await expect.poll(() => page.evaluate(() => window.farlanding.saves.quicksave?.status)).toBe('saved');
  await expect.poll(async () => (await state(page)).quicksave).not.toBe('');
  const saved = (await state(page)).quicksave;
  await page.reload();
  await play(page);
  await expect.poll(async () => (await state(page))?.quicksave, { timeout: 90000 }).toBe(saved);
  await button(page, 'CONTINUE');
  await expect.poll(async () => (await state(page)).tick).toBeGreaterThan(0);
  expect((await state(page)).mission).toBe('conquest');
  expect((await state(page)).campaign_active).toBe(true);
  expect(await page.evaluate(() => window.farlanding.errors)).toEqual([]);
});
}

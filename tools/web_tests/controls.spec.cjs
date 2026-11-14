const { test, expect } = require('@playwright/test');
async function state(page) { return page.evaluate(() => window.farlanding?.diagnostics); }
async function boot(page, query = '') {
  await page.goto('http://127.0.0.1:8071/' + query);
  await page.getByRole('button', { name: 'Play Farlanding' }).click();
  await expect.poll(() => page.evaluate(() => window.farlanding?.ready), { timeout: 90000 }).toBe(true);
  await expect.poll(async () => !!(await state(page))).toBe(true);
}
async function button(page, text) {
  try { await expect.poll(async () => (await state(page)).buttons.some(item => item.text.startsWith(text))).toBe(true); }
  catch (error) { console.log('Missing button', text, JSON.stringify(await state(page))); throw error; }
  const item = (await state(page)).buttons.find(item => item.text.startsWith(text));
  await page.mouse.click(...item.pixel, { delay: 80 });
}

async function option(page, label) {
  await expect.poll(async () => (await state(page)).popups.some(popup => popup.items.some(item => item.startsWith(label)))).toBe(true);
  const popup = (await state(page)).popups.find(popup => popup.items.some(item => item.startsWith(label)));
  const index = popup.items.findIndex(item => item.startsWith(label));
  await page.mouse.click(popup.position[0] + popup.size[0] / 2, popup.position[1] + popup.size[1] * (index + 0.5) / popup.items.length, { delay: 80 });
}

test('menus remain navigable at supported viewports and UI scales', async ({ page }, info) => {
  await boot(page);
  for (const viewport of [{ width: 1280, height: 720 }, { width: 1920, height: 1080 }]) {
    await page.setViewportSize(viewport);
    await expect.poll(async () => {
      const settings = (await state(page)).buttons.find(item => item.text === 'SETTINGS');
      return settings ? Math.abs(settings.pixel[0] - viewport.width / 2) : 999;
    }).toBeLessThan(30);
    for (const scale of [1, 1.15, 1.3]) {
      await button(page, 'SETTINGS');
      await button(page, 'ACCESSIBILITY');
      await button(page, `${Math.round((await state(page)).ui_scale * 100)}%`);
      await option(page, `${Math.round(scale * 100)}%`);
      await expect.poll(async () => (await state(page)).ui_scale).toBe(scale);
      const back = (await state(page)).buttons.find(item => item.text.startsWith('BACK'));
      expect(back.pixel[0]).toBeGreaterThan(0);
      expect(back.pixel[0]).toBeLessThan(viewport.width);
      expect(back.pixel[1]).toBeGreaterThan(0);
      expect(back.pixel[1]).toBeLessThan(viewport.height);
      await page.screenshot({ path: info.outputPath(`settings-${viewport.width}-${scale}.png`) });
      await button(page, 'BACK');
      await expect.poll(async () => (await state(page)).buttons.some(item => item.text === 'ACCESSIBILITY')).toBe(false);
      await expect.poll(async () => (await state(page)).screen).toBe('title');
    }
  }
  expect(await page.evaluate(() => window.farlanding.errors)).toEqual([]);
});

test('modern mouse scheme accepts movement and persists across reload', async ({ page }) => {
  await boot(page, '?mission=conquest');
  await page.keyboard.press('Escape');
  await button(page, 'SETTINGS');
  await button(page, 'Classic');
  await option(page, 'Modern');
  await expect.poll(async () => (await state(page)).scheme).toBe('modern');
  await button(page, 'BACK');
  await button(page, 'RESUME');
  const worker = (await state(page)).units.find(unit => unit.kind === 'concord_fabricator');
  await page.mouse.click(...worker.pixel, { delay: 80 });
  await expect.poll(async () => (await state(page)).selected).toContain(worker.id);
  await page.mouse.click(...(await state(page)).ground[0], { button: 'right', delay: 80 });
  await expect.poll(async () => {
    const current = (await state(page)).units.find(unit => unit.id === worker.id);
    return Math.hypot(current.position[0] - worker.position[0], current.position[2] - worker.position[2]);
  }).toBeGreaterThan(1);
  await expect.poll(() => page.evaluate(() => window.farlanding.saves.settings?.status)).toBe('saved');
  await page.reload();
  await page.getByRole('button', { name: 'Play Farlanding' }).click();
  await expect.poll(async () => (await state(page))?.scheme, { timeout: 90000 }).toBe('modern');
  expect(await page.evaluate(() => window.farlanding.errors)).toEqual([]);
});

test('browser blur pauses until the player resumes', async ({ page }) => {
  await boot(page, '?mission=conquest');
  await page.evaluate(() => window.dispatchEvent(new Event('blur')));
  await expect.poll(async () => (await state(page)).paused).toBe(true);
  await page.evaluate(() => window.dispatchEvent(new Event('focus')));
  expect((await state(page)).paused).toBe(true);
  await button(page, 'RESUME');
  await expect.poll(async () => (await state(page)).paused).toBe(false);
});

const { test, expect } = require('@playwright/test');
test.use({ video: 'off', trace: 'off' });
if (process.env.WEB_SOAK) {
  test('30-minute landing and menu session remains usable', async ({ page }, info) => {
    test.setTimeout(1900000);
    const state = () => page.evaluate(() => window.farlanding?.diagnostics);
    async function button(text) {
      await expect.poll(async () => (await state())?.buttons.some(item => item.text.startsWith(text))).toBe(true);
      const target = (await state()).buttons.find(item => item.text.startsWith(text));
      await page.mouse.click(...target.pixel, { delay: 80 });
    }
    const started = Date.now();
    const cycles = [];
    await page.goto('http://127.0.0.1:8071/?mission=conquest');
    await page.getByRole('button', { name: 'Play Farlanding' }).click();
    while (Date.now() - started < 1800000) {
      await expect.poll(async () => (await state())?.tick, { timeout: 90000 }).toBeGreaterThan(0);
      const worker = (await state()).units.find(unit => unit.kind === 'concord_fabricator');
      await page.mouse.click(...worker.pixel, { delay: 80 });
      await expect.poll(async () => (await state()).selected).toContain(worker.id);
      await page.mouse.click(...(await state()).ground[0], { delay: 80 });
      await expect.poll(async () => (await state()).tick, { timeout: 90000 }).toBeGreaterThan(600);
      await page.keyboard.press('k');
      await expect.poll(() => page.evaluate(() => window.farlanding.saves.quicksave?.status)).toBe('saved');
      await page.keyboard.press('Escape');
      await button('QUIT TO MISSIONS');
      await button('BACK');
      await expect.poll(async () => (await state()).screen).toBe('title');
      const heap = await page.evaluate(() => performance.memory?.usedJSHeapSize || null);
      cycles.push({ elapsedSeconds: (Date.now() - started) / 1000, jsHeapBytes: heap });
      console.log('Soak cycle', cycles.length, JSON.stringify(cycles.at(-1)));
      expect(await page.evaluate(() => window.farlanding.errors)).toEqual([]);
      await button('SINGLE MISSIONS');
      await page.mouse.click(600, 285, { delay: 80 });
      await button('START LANDING');
    }
    await info.attach('soak', { body: JSON.stringify({ cycles, note: 'JS heap only; no claim about GPU or WebAssembly allocator memory.' }, null, 2), contentType: 'application/json' });
  });
}

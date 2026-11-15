const { test, expect } = require('@playwright/test');
const { play } = require('./launch.cjs');
const state = page => page.evaluate(() => window.farlanding?.diagnostics);
async function click(page, text) {
  await expect.poll(async () => (await state(page))?.buttons.some(b => b.text.startsWith(text))).toBe(true);
  const b = (await state(page)).buttons.find(b => b.text.startsWith(text));
  const view = page.viewportSize();
  expect(b.pixel[0]).toBeGreaterThan(0); expect(b.pixel[0]).toBeLessThan(view.width);
  expect(b.pixel[1]).toBeGreaterThan(0); expect(b.pixel[1]).toBeLessThan(view.height);
  await page.mouse.click(...b.pixel, { delay: 80 });
}
async function capture(page, info, name) {
  await page.screenshot({ path: info.outputPath(`${name}.png`) });
  await info.attach(name, { body: JSON.stringify(await state(page)), contentType: 'application/json' });
  expect(await page.evaluate(() => window.farlanding.errors)).toEqual([]);
}
if (process.env.WEB_UI_QUALIFY) {
  for (const scale of [1, 1.3]) {
    test(`field-kit screens at 2000x754 and ${scale * 100}% UI`, async ({ page }, info) => {
      test.setTimeout(240000);
      await page.setViewportSize({ width: 2000, height: 754 });
      await page.goto('http://127.0.0.1:8071/'); await play(page);
      await expect.poll(async () => (await state(page))?.screen, { timeout: 90000 }).toBe('title');
      await click(page, 'SETTINGS'); await click(page, 'ACCESSIBILITY');
      await click(page, '100%');
      await expect.poll(async () => (await state(page)).popups.length).toBeGreaterThan(0);
      const popup = (await state(page)).popups.find(p => p.items.some(t => t.startsWith(`${scale * 100}%`)));
      const index = popup.items.findIndex(t => t.startsWith(`${scale * 100}%`));
      await page.mouse.click(popup.position[0] + popup.size[0] / 2,
        popup.position[1] + popup.size[1] * (index + 0.5) / popup.items.length, { delay: 80 });
      await expect.poll(async () => (await state(page)).ui_scale).toBe(scale);
      await capture(page, info, 'accessibility'); await click(page, 'GENERAL');
      await capture(page, info, 'settings'); await click(page, 'BACK');
      await capture(page, info, 'title');
      for (const [label, name] of [['HOW TO PLAY', 'help'], ['CONTROLS', 'controls'], ['CREDITS', 'credits']]) {
        await click(page, label); await capture(page, info, name); await click(page, 'BACK');
      }
      await click(page, 'SINGLE MISSIONS'); await capture(page, info, 'missions');
      const card = (await state(page)).buttons.find(b => b.text === '');
      expect(card, 'first unlocked mission card').toBeTruthy();
      await page.mouse.click(...card.pixel, { delay: 80 });
      await expect.poll(async () => (await state(page)).buttons.some(b => b.text.startsWith('START LANDING'))).toBe(true);
      await capture(page, info, 'briefing'); await click(page, 'BACK');
      await expect.poll(async () => (await state(page)).buttons.some(b => b.text === '')).toBe(true);
      await click(page, 'BACK');
      await expect.poll(async () => (await state(page)).screen).toBe('title');
      await click(page, 'NEW CAMPAIGN'); await capture(page, info, 'campaign-setup'); await click(page, 'START');
      await expect.poll(async () => (await state(page)).screen).toBe('star_map');
      await expect.poll(async () => (await state(page)).buttons.some(b => b.name === 'kessel_proving')).toBe(true);
      const landing = (await state(page)).buttons.find(b => b.name === 'kessel_proving');
      await capture(page, info, 'star-map'); await click(page, 'MERIDIAN');
      await capture(page, info, 'meridian'); await click(page, 'TECH WEB'); await capture(page, info, 'tech-web');
      await click(page, 'LOADOUT'); await capture(page, info, 'loadout'); await click(page, 'STAR MAP');
      await expect.poll(async () => (await state(page)).screen).toBe('star_map');
      expect(landing).toBeTruthy(); await page.mouse.click(...landing.pixel, { delay: 80 });
      await click(page, 'LAUNCH'); await click(page, 'START LANDING');
      await expect.poll(async () => (await state(page)).tick, { timeout: 90000 }).toBeGreaterThan(0);
      await click(page, 'GOT IT'); await capture(page, info, 'hud');
      await page.keyboard.press('c');
      await expect.poll(async () => (await state(page)).buttons.some(b => b.text.startsWith('Close'))).toBe(true);
      await expect.poll(async () => (await state(page)).buttons.some(b => b.text === 'GOT IT')).toBe(false);
      await capture(page, info, 'survey-log'); await click(page, 'Close');
      await page.keyboard.press('Escape');
      await expect.poll(async () => (await state(page)).paused).toBe(true);
      await expect.poll(async () => (await state(page)).buttons.some(b => b.text === 'GOT IT')).toBe(false);
      await capture(page, info, 'pause');
      await click(page, 'CONTROLS'); await capture(page, info, 'pause-controls'); await click(page, 'BACK');
      await click(page, 'RESUME');
      await expect.poll(async () => (await state(page)).paused).toBe(false);
      if (scale === 1.3) {
        await page.setViewportSize({ width: 1152, height: 648 });
        await page.goto('http://127.0.0.1:8071/?mission=conquest'); await play(page);
        await expect.poll(async () => (await state(page))?.tick, { timeout: 90000 }).toBeGreaterThan(0);
        expect((await state(page)).ui_scale).toBe(scale);
        const worker = (await state(page)).units.find(u => u.faction === 0 && u.kind === 'concord_fabricator');
        await page.mouse.click(...worker.pixel, { delay: 80 });
        await expect.poll(async () => (await state(page)).selected).toContain(worker.id);
        for (let digit = 1; digit <= 9; digit++) await page.keyboard.press(`Alt+${digit}`);
        await expect.poll(async () => (await state(page)).buttons.filter(b => /^\d · 1$/.test(b.text)).length).toBe(9);
        await expect.poll(async () => {
          const s = (await state(page)).command_scroll;
          return s && s.maximum > s.page && s.rect[3] > 0;
        }).toBe(true);
        const scroll = (await state(page)).command_scroll;
        const [sx, sy, sw, sh] = scroll.rect;
        await page.mouse.move(sx + sw * scroll.page / scroll.maximum / 2, sy + sh / 2);
        await page.mouse.down();
        await page.mouse.move(sx + sw - 2, sy + sh / 2, { steps: 8 });
        await page.mouse.up();
        await expect.poll(async () => {
          const last = (await state(page)).buttons.find(b => b.text.startsWith('Survey Lab'));
          return last && last.pixel[0] > 0 && last.pixel[0] < 850;
        }).toBe(true);
        await capture(page, info, 'narrow-commands');
        await click(page, 'Survey Lab');
        await expect.poll(async () => (await state(page)).placing).toBe(true);
        await page.keyboard.press('Escape');
      }
    });
  }
}

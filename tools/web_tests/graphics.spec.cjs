const { test, expect } = require('@playwright/test');
const { play } = require('./launch.cjs');

const state = page => page.evaluate(() => window.farlanding?.diagnostics);

test.describe('Retina layout', () => {
  test.use({ deviceScaleFactor: 2 });
  test('Retina keeps readable menus and real CSS-coordinate input', async ({ page }, info) => {
    await boot(page, 'low');
    expect((await state(page)).display_scale).toBe(2);
    await button(page, 'SETTINGS');
    await expect.poll(async () => (await state(page)).buttons.some(item => item.text === 'ACCESSIBILITY')).toBe(true);
    await page.screenshot({ path: info.outputPath('retina-settings.png') });
    await button(page, 'BACK');
    await expect.poll(async () => (await state(page)).screen).toBe('title');
    expect(await page.evaluate(() => window.farlanding.errors)).toEqual([]);
  });
});

async function boot(page, choice = 'saved') {
  await page.goto('http://127.0.0.1:8071/');
  await play(page, choice);
  await expect.poll(async () => (await state(page))?.quality, { timeout: 90000 }).toBeTruthy();
}
async function button(page, text) {
  await expect.poll(async () => (await state(page)).buttons.some(b => b.text.startsWith(text))).toBe(true);
  const target = (await state(page)).buttons.find(b => b.text.startsWith(text));
  await page.mouse.click(...target.pixel, { delay: 80 });
}
async function legacyProfile(page) {
  await boot(page, 'low');
  await expect.poll(() => page.evaluate(() => window.farlanding.saves.settings?.status)).toBe('saved');
  await page.evaluate(async () => {
    const db = await new Promise((resolve, reject) => {
      const request = indexedDB.open('/userfs');
      request.onsuccess = () => resolve(request.result);
      request.onerror = () => reject(request.error);
    });
    await new Promise((resolve, reject) => {
      const tx = db.transaction('FILE_DATA', 'readwrite');
      const store = tx.objectStore('FILE_DATA');
      const cursor = store.openCursor();
      cursor.onsuccess = () => {
        const item = cursor.result;
        if (!item) return;
        if (String(item.key).endsWith('/settings.cfg')) {
          const record = item.value;
          let text = new TextDecoder().decode(record.contents);
          text = text.replace(/^graphics_defaults_version=.*\n/gm, '').replace(/^msaa_3d=.*\n/gm, '');
          text = text.replace(/^music_volume=.*$/m, 'music_volume=0.42');
          text = text.replace(/^control_scheme=.*$/m, 'control_scheme="modern"');
          record.contents = new TextEncoder().encode(text);
          record.timestamp = new Date(Date.now() + 1000);
          item.update(record);
        }
        item.continue();
      };
      tx.oncomplete = resolve;
      tx.onerror = () => reject(tx.error);
    });
    db.close();
  });
  await page.reload();
  await play(page, 'saved');
  await expect.poll(async () => (await state(page))?.graphics_upgrade_available, { timeout: 90000 }).toBe(true);
}

test('a fresh browser starts at High, full resolution and 2x MSAA', async ({ page }, info) => {
  await boot(page);
  expect((await state(page)).quality).toBe('high');
  expect((await state(page)).render_scale).toBe(1);
  expect((await state(page)).msaa).toBe(1);
  expect((await state(page)).display_scale).toBe(await page.evaluate(() => devicePixelRatio));
  expect((await state(page)).graphics_upgrade_available).toBe(false);
  await info.attach('fresh-graphics', { body: JSON.stringify(await state(page)), contentType: 'application/json' });
});

test('the launcher Performance choice persists when Saved is used on reload', async ({ page }) => {
  await boot(page, 'low');
  await expect.poll(() => page.evaluate(() => window.farlanding.saves.settings?.status)).toBe('saved');
  await page.reload();
  await play(page, 'saved');
  await expect.poll(async () => (await state(page))?.quality, { timeout: 90000 }).toBe('low');
  expect((await state(page)).render_scale).toBe(0.5);
  expect((await state(page)).msaa).toBe(0);
  expect((await state(page)).graphics_upgrade_available).toBe(false);
});

test('legacy players can keep their graphics without a repeated upgrade prompt', async ({ page }) => {
  await legacyProfile(page);
  await button(page, 'KEEP CURRENT');
  await expect.poll(async () => (await state(page)).graphics_upgrade_available).toBe(false);
  await expect.poll(() => page.evaluate(() => window.farlanding.saves.settings?.status)).toBe('saved');
  await page.reload();
  await play(page, 'saved');
  await expect.poll(async () => (await state(page))?.graphics_defaults_version, { timeout: 90000 }).toBe(2);
  expect((await state(page)).quality).toBe('low');
  expect((await state(page)).scheme).toBe('modern');
  expect((await state(page)).music_volume).toBe(0.42);
  expect((await state(page)).graphics_upgrade_available).toBe(false);
});

if (process.env.WEB_GRAPHICS_QUALIFY) {
  test('legacy players can upgrade to High while retaining unrelated preferences', async ({ page }, info) => {
    await legacyProfile(page);
    await button(page, 'USE HIGH GRAPHICS');
    await expect.poll(async () => (await state(page)).quality).toBe('high');
    expect((await state(page)).render_scale).toBe(1);
    expect((await state(page)).msaa).toBe(1);
    expect((await state(page)).scheme).toBe('modern');
    expect((await state(page)).music_volume).toBe(0.42);
    await expect.poll(() => page.evaluate(() => window.farlanding.saves.settings?.status)).toBe('saved');
    await page.reload();
    await play(page, 'saved');
    await expect.poll(async () => (await state(page))?.quality, { timeout: 90000 }).toBe('high');
    expect((await state(page)).graphics_upgrade_available).toBe(false);
    await page.screenshot({ path: info.outputPath('high-title.png') });
  });
}

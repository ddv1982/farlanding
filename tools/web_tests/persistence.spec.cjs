const { test, expect } = require('@playwright/test');
test('quicksave reaches IndexedDB and survives immediate reload', async ({ page }) => {
  await page.goto('http://127.0.0.1:8071/?mission=conquest');
  await page.getByRole('button', { name: 'Play Farlanding' }).click();
  await expect.poll(() => page.evaluate(() => window.farlanding?.diagnostics?.tick), { timeout: 90000 }).toBeGreaterThan(0);
  await page.keyboard.press('k');
  await expect.poll(() => page.evaluate(() => window.farlanding.diagnostics.quicksave)).not.toBe('');
  await expect.poll(() => page.evaluate(() => window.farlanding.diagnostics.notice)).toBe('Saved to Quicksave.');
  const saved = await page.evaluate(() => window.farlanding.diagnostics.quicksave);
  await page.reload();
  await page.getByRole('button', { name: 'Play Farlanding' }).click();
  await expect.poll(() => page.evaluate(() => window.farlanding?.diagnostics?.quicksave), { timeout: 90000 }).toBe(saved);
});

test('a corrupt persisted landing is refused after reload', async ({ page }) => {
  await page.goto('http://127.0.0.1:8071/?mission=conquest');
  await page.getByRole('button', { name: 'Play Farlanding' }).click();
  await expect.poll(() => page.evaluate(() => window.farlanding?.diagnostics?.tick), { timeout: 90000 }).toBeGreaterThan(0);
  await page.keyboard.press('k');
  await expect.poll(() => page.evaluate(() => window.farlanding.saves.quicksave?.status)).toBe('saved');
  await page.evaluate(async () => {
    await new Promise((resolve, reject) => {
      const request = indexedDB.open('/userfs');
      request.onerror = () => reject(request.error);
      request.onsuccess = () => {
        const db = request.result;
        const transaction = db.transaction('FILE_DATA', 'readwrite');
        const store = transaction.objectStore('FILE_DATA');
        const path = '/userfs/godot/app_userdata/Farlanding/saves/quicksave.save';
        const read = store.get(path);
        read.onsuccess = () => {
          const file = read.result;
          file.contents[0] = 88;
          store.put(file, path);
        };
        transaction.oncomplete = () => { db.close(); resolve(); };
        transaction.onerror = () => { db.close(); reject(transaction.error); };
      };
    });
  });
  await page.reload();
  await page.getByRole('button', { name: 'Play Farlanding' }).click();
  await expect.poll(() => page.evaluate(() => window.farlanding?.diagnostics?.tick), { timeout: 90000 }).toBeGreaterThan(0);
  await page.keyboard.press('l');
  await expect.poll(() => page.evaluate(() => window.farlanding.diagnostics.notice)).toBe('This is not a Farlanding save.');
  expect(await page.evaluate(() => window.farlanding.diagnostics.mission)).toBe('conquest');
});

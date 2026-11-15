const { createHash } = require('node:crypto');
const { play } = require('./launch.cjs');
const { test, expect } = require('@playwright/test');

test('launcher explains graphics defaults and keeps launch options secondary', async ({ page }, info) => {
  await page.goto('http://127.0.0.1:8070/');
  await expect(page.getByRole('button', { name: 'Play Farlanding' })).toBeVisible();
  await expect(page.getByLabel('Graphics preset')).toBeHidden();
  await expect.poll(() => page.locator('.identity img').evaluate(image => image.complete && image.naturalWidth > 0)).toBe(true);
  await page.screenshot({ path: info.outputPath('browser-launcher.png') });
  await page.getByText('Launch options', { exact: true }).click();
  await expect(page.getByLabel('Graphics preset')).toHaveValue('saved');
  await expect(page.locator('#graphics-help')).toContainText('On your first visit, the game starts on High.');
  await page.getByLabel('Graphics preset').selectOption('low');
  await expect(page.getByLabel('Graphics preset')).toHaveValue('low');
  await page.setViewportSize({ width: 360, height: 640 });
  const button = await page.getByRole('button', { name: 'Play Farlanding' }).boundingBox();
  expect(button.x).toBeGreaterThanOrEqual(0);
  expect(button.x + button.width).toBeLessThanOrEqual(360);
  await page.screenshot({ path: info.outputPath('browser-launcher-narrow.png') });
});

// Browsers keep a separate favicon cache: changing the image at the old URL is
// insufficient for returning players. The export must give new artwork a new URL.
test('the tab icon is versioned and stays Farlanding artwork after launch', async ({ page }) => {
  await page.goto('http://127.0.0.1:8070/');
  const icon = page.locator('link[rel="icon"]');
  await expect(icon).toHaveCount(1);
  const href = await icon.getAttribute('href');
  expect(href).toMatch(/^index\.icon\.png\?v=[a-f0-9]{16}$/);
  const response = await page.request.get(new URL(href, page.url()).href);
  expect(response.ok()).toBe(true);
  expect(new URL(href, page.url()).searchParams.get('v')).toBe(
    createHash('sha256').update(await response.body()).digest('hex').slice(0, 16));
  const artworkURL = await page.locator('.identity img').evaluate(image => image.src);
  async function iconPixels() {
    return page.evaluate(async artwork => {
      const urls = [document.querySelector('link[rel="icon"]').href, artwork];
      const pixels = await Promise.all(urls.map(async url => {
        const bitmap = await createImageBitmap(await (await fetch(url)).blob());
        const canvas = document.createElement('canvas');
        canvas.width = canvas.height = 32;
        const context = canvas.getContext('2d');
        context.drawImage(bitmap, 0, 0, 32, 32);
        const result = Array.from(context.getImageData(0, 0, 32, 32).data);
        bitmap.close();
        return result;
      }));
      return pixels[0].every((value, index) => value === pixels[1][index]);
    }, artworkURL);
  }
  await expect.poll(iconPixels).toBe(true);
  await play(page);
  await expect.poll(() => page.evaluate(() => window.farlanding?.ready), { timeout: 90000 }).toBe(true);
  await expect(icon).toHaveCount(1);
  await expect.poll(iconPixels).toBe(true);
  expect(await page.evaluate(() => window.farlanding.errors)).toEqual([]);
});

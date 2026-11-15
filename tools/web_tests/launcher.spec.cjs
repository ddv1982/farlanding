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

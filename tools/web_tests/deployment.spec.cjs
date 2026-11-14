const { test, expect } = require('@playwright/test');

if (process.env.WEB_DEPLOYMENT_URL && !process.env.WEB_DEPLOYMENT_PUBLIC_ONLY) {
  test('production serves the tested release and reaches a playable landing', async ({ page }, info) => {
    const url = process.env.WEB_DEPLOYMENT_URL;
    const errors = [];
    page.on('pageerror', error => errors.push(String(error)));
    page.on('console', entry => { if (entry.type() === 'error') errors.push(entry.text()); });
    await expect.poll(async () => {
      const response = await page.request.get(`${url}/manifest.json`);
      return response.ok() ? (await response.json()).commit : null;
    }, { timeout: 60000 }).toBe(process.env.WEB_DEPLOYMENT_COMMIT);
    for (const path of ['/', '/index.wasm', '/index.pck']) {
      const response = await page.request.head(url + path);
      expect(response.ok()).toBe(true);
      expect(response.headers()['cross-origin-opener-policy']).toBe('same-origin');
      expect(response.headers()['cross-origin-embedder-policy']).toBe('require-corp');
      if (path.endsWith('.wasm')) expect(response.headers()['content-type']).toContain('application/wasm');
    }
    const manifest = await (await page.request.get(`${url}/manifest.json`)).json();
    expect(manifest.dirty).toBe(false);
    expect(manifest.preset).toBe('Web');
    await page.goto(url);
    await page.getByRole('button', { name: 'Play Farlanding' }).click();
    await expect.poll(() => page.evaluate(() => window.farlanding?.ready), { timeout: 90000 }).toBe(true);
    expect(await page.evaluate(() => crossOriginIsolated)).toBe(true);
    expect(await page.evaluate(() => window.farlanding.diagnostics)).toBeUndefined();
    await page.mouse.click(630, 388, { delay: 80 });
    await page.mouse.click(600, 285, { delay: 80 });
    const landing = page.waitForEvent('console', {
      predicate: entry => entry.text().includes('kessel_proving: 18 resource nodes and the bases placed'), timeout: 90000,
    });
    await page.mouse.click(850, 522, { delay: 80 });
    await landing;
    await page.mouse.click(580, 385, { delay: 80 });
    expect(await page.evaluate(() => window.farlanding.errors)).toEqual([]);
    expect(errors).toEqual([]);
    await page.screenshot({ path: info.outputPath('production-landing.png') });
    await info.attach('release-manifest', { body: JSON.stringify(manifest), contentType: 'application/json' });
  });
}

if (process.env.WEB_DEPLOYMENT_URL && process.env.WEB_DEPLOYMENT_PUBLIC_ONLY) {
  test('the production domain exposes the current release without authentication', async () => {
    const url = process.env.WEB_DEPLOYMENT_URL;
    // Node fetch sends no Playwright protection headers, cookies, or Vercel token.
    await expect.poll(async () => {
      const response = await fetch(`${url}/manifest.json`);
      return response.ok && response.headers.get('content-type')?.includes('application/json')
        ? (await response.json()).commit : null;
    }, { timeout: 60000 }).toBe(process.env.WEB_DEPLOYMENT_COMMIT);
    for (const path of ['/', '/index.wasm', '/index.pck']) {
      const response = await fetch(url + path, { method: 'HEAD' });
      expect(response.status).toBe(200);
      expect(new URL(response.url).origin).toBe(new URL(url).origin);
      expect(response.headers.get('cross-origin-opener-policy')).toBe('same-origin');
      expect(response.headers.get('cross-origin-embedder-policy')).toBe('require-corp');
      if (path.endsWith('.wasm')) expect(response.headers.get('content-type')).toContain('application/wasm');
    }
  });
}

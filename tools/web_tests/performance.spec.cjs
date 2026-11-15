const { play } = require('./launch.cjs');
const { test, expect } = require('@playwright/test');
test.use({ video: 'off', trace: 'off' });
if (process.env.WEB_PERFORMANCE) {
  test(process.env.WEB_BENCH_NORMAL ? 'normal Web landing reports measured frame and simulation costs' : '233-unit Web battle reports measured frame and simulation costs', async ({ page }, info) => {
    test.setTimeout(180000);
    const errors = [];
    page.on('pageerror', error => errors.push(String(error)));
    const start = Date.now();
    await page.goto('http://127.0.0.1:8071/?bench' + (process.env.WEB_BENCH_SECONDS === '30' ? '&seconds=30' : '') + (process.env.WEB_BENCH_QUALITY === 'high' ? '&quality=high' : '') + (process.env.WEB_BENCH_MSAA === '2' ? '&msaa=2' : '') + (process.env.WEB_BENCH_NORMAL ? '&normal' : ''));
    await play(page);
    await expect.poll(() => page.evaluate(() => window.farlanding?.ready), { timeout: 90000 }).toBe(true);
    const startupMs = Date.now() - start;
    const device = await page.evaluate(() => {
      const gl = document.querySelector('canvas').getContext('webgl2');
      const debug = gl.getExtension('WEBGL_debug_renderer_info');
      return { renderer: gl.getParameter(debug ? debug.UNMASKED_RENDERER_WEBGL : gl.RENDERER), userAgent: navigator.userAgent };
    });
    await expect.poll(() => page.evaluate(() => window.farlanding?.benchmark), { timeout: 140000 }).toBeTruthy();
    const report = await page.evaluate(() => window.farlanding);
    expect(report.errors).toEqual([]);
    expect(errors).toEqual([]);
    if (!process.env.WEB_BENCH_NORMAL) expect(report.benchmark[0]).toContain('peak 233 units');
    const dimensions = await page.evaluate(() => ({ canvas: [document.querySelector('canvas').width, document.querySelector('canvas').height], css: [innerWidth, innerHeight], dpr: devicePixelRatio }));
    await info.attach('benchmark', { body: JSON.stringify({ startupMs, device, report }, null, 2), contentType: 'application/json' });
    console.log(JSON.stringify({ startupMs, device, dimensions, profile: report.benchmarkProfile, benchmark: report.benchmark }));
    await page.screenshot({ path: info.outputPath('battle.png') });
  });
}

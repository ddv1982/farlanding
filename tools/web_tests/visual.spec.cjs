const { play } = require('./launch.cjs');
const { test, expect } = require('@playwright/test');

if (process.env.WEB_VISUALS) {
  test.use({ video: 'off', trace: 'off' });
  for (const mission of ['orbit', 'conquest', 'thalassa_recovery', 'emberfall_conquest', 'verdance_conquest', 'hollow_power']) {
    for (const profile of (process.env.WEB_VISUAL_BASELINE ? ['low', 'high'] : ['high'])) {
      test(`visual reference ${mission} ${profile}`, async ({ page }, info) => {
        await page.goto(`http://127.0.0.1:8071/?visual=${mission}&quality=${profile}&scale=${profile === 'low' ? '0.5' : '1'}`);
        await play(page);
        await expect.poll(() => page.evaluate(() => window.farlanding?.visual), { timeout: 90000 }).toBeTruthy();
        const report = await page.evaluate(() => ({ ...window.farlanding.visual,
          canvas: [document.querySelector('canvas').width, document.querySelector('canvas').height],
          css: [innerWidth, innerHeight], dpr: devicePixelRatio,
        }));
        expect(report.quality).toBe(profile);
        expect(report.canvas).toEqual(report.css.map(size => size * report.dpr));
        expect(await page.evaluate(() => window.farlanding.errors)).toEqual([]);
        await page.screenshot({ path: info.outputPath(`${mission}-${profile}.png`) });
        await info.attach('visual-profile', { body: JSON.stringify(report), contentType: 'application/json' });
        console.log(JSON.stringify(report));
      });
    }
  }
}

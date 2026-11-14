const { test, expect } = require('@playwright/test');
const { captureAudio } = require('./audio-capture.cjs');
test.use({ video: 'off', trace: 'off' });
if (process.env.WEB_LATENCY) {
  test('measures keydown to captured UI cue', async ({ page }, info) => {
    await page.addInitScript(captureAudio);
    await page.goto('http://127.0.0.1:8071/?latency');
    await page.getByRole('button', { name: 'Play Farlanding' }).click();
    await expect.poll(() => page.evaluate(() => window.farlanding?.ready), { timeout: 90000 }).toBe(true);
    await page.locator('#canvas').click();
    await page.evaluate(() => {
      window.cueLatencies = [];
      window.cueSilentFrames = 0;
      let pressed = null;
      const samples = new Float32Array(window.audioCapture.analyser.fftSize);
      window.addEventListener('keydown', event => { if (event.code === 'Space') pressed = performance.now(); }, true);
      function read() {
        window.audioCapture.analyser.getFloatTimeDomainData(samples);
        window.cueSilentFrames = samples.some(value => Math.abs(value) > 0.00001) ? 0 : window.cueSilentFrames + 1;
        if (pressed !== null && samples.some(value => Math.abs(value) > 0.002)) {
          window.cueLatencies.push(performance.now() - pressed);
          pressed = null;
        }
        requestAnimationFrame(read);
      }
      requestAnimationFrame(read);
    });
    for (let index = 0; index < 6; index++) {
      await expect.poll(() => page.evaluate(() => window.cueSilentFrames)).toBeGreaterThanOrEqual(6);
      await page.keyboard.press('Space');
      try { await expect.poll(() => page.evaluate(() => window.cueLatencies.length), { timeout: 5000 }).toBe(index + 1); }
      catch (error) { console.log('Latency diagnostic', JSON.stringify(await page.evaluate(() => ({ game:window.farlanding, latencies:window.cueLatencies, rms:window.audioCapture.rms, audioState:window.audioCapture.context.state, focus:document.activeElement?.id })))); throw error; }
    }
    const result = await page.evaluate(() => ({ measurementsMs: window.cueLatencies.slice(1), driverLatencyMs: window.farlanding.audioDriverLatencyMs, sampleRate: window.audioCapture.context.sampleRate }));
    console.log('Cue latency', JSON.stringify(result));
    await info.attach('cue-latency', { body: JSON.stringify(result, null, 2), contentType: 'application/json' });
  });
}

const { test, expect } = require('@playwright/test');
const { captureAudio } = require('./audio-capture.cjs');
test('browser emits and records actual streamed audio after a gesture', async ({ page }, info) => {
  await page.addInitScript(captureAudio);
  await page.goto('http://127.0.0.1:8070');
  await page.getByRole('button', { name: 'Play Farlanding' }).click();
  await expect.poll(() => page.evaluate(() => window.farlanding?.ready), { timeout: 90000 }).toBe(true);
  await page.mouse.click(630, 396, { delay: 80 });
  await expect.poll(() => page.evaluate(() => window.audioCapture.rms)).toBeGreaterThan(0.0001);
  await expect.poll(() => page.evaluate(() => window.audioCapture.chunks.length)).toBeGreaterThanOrEqual(5);
  const capture = await page.evaluate(async () => {
    const recorder = window.audioCapture.recorder;
    await new Promise(resolve => { recorder.onstop = resolve; recorder.stop(); });
    return Array.from(new Uint8Array(await new Blob(window.audioCapture.chunks).arrayBuffer()));
  });
  expect(capture.length).toBeGreaterThan(1000);
  await info.attach('actual-browser-audio.webm', { body: Buffer.from(capture), contentType: 'audio/webm' });
});

if (process.env.WEB_AUDIO_QA) {
  test('existing real-mixer audio suite passes in the Web runtime', async ({ page }, info) => {
    test.setTimeout(600000);
    const logs = [];
    page.on('console', entry => logs.push({ type: entry.type(), text: entry.text() }));
    await page.addInitScript(captureAudio);
    await page.goto('http://127.0.0.1:8071/?audio');
    await page.getByRole('button', { name: 'Play Farlanding' }).click();
    await expect.poll(() => page.evaluate(() => window.farlanding?.ready), { timeout: 90000 }).toBe(true);
    await page.mouse.click(600, 360, { delay: 80 });
    await expect.poll(() => page.evaluate(() => window.farlanding.audioQa), { timeout: 540000 }).toBeTruthy();
    const result = await page.evaluate(() => window.farlanding);
    await info.attach('web-audio-suite', { body: JSON.stringify({ result, logs }, null, 2), contentType: 'application/json' });
    console.log('Web audio QA', JSON.stringify(result));
    expect(result.audioQa.tests).toBeGreaterThan(400);
    expect(logs.filter(entry => entry.type === 'error' || /GUT ERROR/.test(entry.text))).toEqual([]);
    expect(result.audioQa.failures).toBe(0);
    expect(result.errors).toEqual([]);
    const capture = await page.evaluate(async () => {
      const recorder = window.audioCapture.recorder;
      if (recorder?.state !== 'inactive') await new Promise(resolve => { recorder.onstop = resolve; recorder.stop(); });
      return Array.from(new Uint8Array(await new Blob(window.audioCapture.chunks).arrayBuffer()));
    });
    await info.attach('web-audio-suite.webm', { body: Buffer.from(capture), contentType: 'audio/webm' });
  });
}

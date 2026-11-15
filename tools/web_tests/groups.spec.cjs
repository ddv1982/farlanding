const { play } = require('./launch.cjs');
const { test, expect } = require('@playwright/test');

async function state(page) { return page.evaluate(() => window.farlanding?.diagnostics); }
async function button(page, label) {
  await expect.poll(async () => (await state(page))?.buttons.some(b => b.text.startsWith(label))).toBe(true);
  const target = (await state(page)).buttons.find(b => b.text.startsWith(label));
  await page.mouse.click(...target.pixel, { delay: 80 });
}
const sorted = ids => [...ids].sort((a, b) => a - b);

// Ctrl/Cmd + a number belongs to the browser (tabs); Alt + the number reaches the game.
test('Alt+1 stores a control group and 1 selects it again in the browser build', async ({ page }, info) => {
  await page.goto('http://127.0.0.1:8071/?mission=conquest');
  await play(page);
  await expect.poll(() => page.evaluate(() => window.farlanding?.ready), { timeout: 90000 }).toBe(true);
  await expect.poll(async () => (await state(page))?.mission).toBe('conquest');
  await button(page, 'GOT IT');
  const view = page.viewportSize();
  const onScreen = unit => unit.faction === 0 && unit.pixel[0] > 40 && unit.pixel[0] < view.width - 40
    && unit.pixel[1] > 80 && unit.pixel[1] < view.height - 200;
  await expect.poll(async () => (await state(page)).units.filter(onScreen).length).toBeGreaterThan(1);
  const [first, second] = (await state(page)).units.filter(onScreen);
  await page.mouse.click(...first.pixel, { delay: 80 });
  await expect.poll(async () => (await state(page)).selected).toContain(first.id);
  await page.keyboard.down('Shift');
  await page.mouse.click(...second.pixel, { delay: 80 });
  await page.keyboard.up('Shift');
  await expect.poll(async () => (await state(page)).selected).toContain(second.id);
  let group = sorted((await state(page)).selected);
  expect(group.length).toBeGreaterThan(1);

  await page.keyboard.press('Alt+1');
  // The HUD's group bar shows group 1 with its unit count.
  await expect.poll(async () => (await state(page)).buttons.some(b => b.text === `1 · ${group.length}`)).toBe(true);
  // The Hauler starts mining immediately; a sampled position can be stale on
  // software-rendered CI by the time the click arrives. Use the idle Surveyor.
  const third = (await state(page)).units.find(unit => onScreen(unit)
    && unit.kind === 'concord_surveyor' && !group.includes(unit.id));
  expect(third, 'the visible idle Surveyor can be added').toBeTruthy();
  await page.mouse.click(...third.pixel, { delay: 80 });
  await expect.poll(async () => (await state(page)).selected).toEqual([third.id]);
  await page.keyboard.press('Shift+1');
  group = sorted([...group, third.id]);
  await expect.poll(async () => (await state(page)).buttons.some(b => b.text === `1 · ${group.length}`)).toBe(true);
  await page.screenshot({ path: info.outputPath('stored-group.png') });

  // Classic scheme: right click deselects.
  await page.mouse.click(...(await state(page)).ground[0], { button: 'right', delay: 80 });
  await expect.poll(async () => (await state(page)).selected).toEqual([]);

  await page.keyboard.press('1');
  await expect.poll(async () => sorted((await state(page)).selected)).toEqual(group);

  // Clicking the badge does the same.
  await page.mouse.click(...(await state(page)).ground[0], { button: 'right', delay: 80 });
  await expect.poll(async () => (await state(page)).selected).toEqual([]);
  await button(page, `1 · ${group.length}`);
  await expect.poll(async () => sorted((await state(page)).selected)).toEqual(group);
  expect(await page.evaluate(() => window.farlanding.errors)).toEqual([]);
});

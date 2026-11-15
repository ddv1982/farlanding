// Select a normal player-facing profile. CI's software renderer is not a player default.
async function play(page, choice) {
  const profile = choice ?? process.env.WEB_GRAPHICS_PROFILE ??
    (process.env.WEB_SOFTWARE || process.env.CI ? 'low' : 'saved');
  await page.getByLabel('Graphics', { exact: true }).selectOption(profile);
  await page.getByRole('button', { name: 'Play Farlanding' }).click();
}
module.exports = { play };

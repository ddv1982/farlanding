// Release smoke runs at the pinned 1280x720 viewport on a fresh profile.
// Keep the actual title-menu pointer route shared by local and staged checks.
async function openSingleMissions(page) {
  await page.locator('#launch').waitFor({ state: 'detached' });
  await page.mouse.click(640, 344, { delay: 80 });
}
module.exports = { openSingleMissions };

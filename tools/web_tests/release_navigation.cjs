// Release smoke uses a fresh profile at the pinned 1280x720 viewport.
// Keep its actual pointer route shared by local and staged checks.
async function openSingleMissions(page) {
  await page.locator('#launch').waitFor({ state: 'detached' });
  await page.mouse.click(640, 401, { delay: 80 });
}
module.exports = { openSingleMissions };

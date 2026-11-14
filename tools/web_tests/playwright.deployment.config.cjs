const { defineConfig } = require('@playwright/test');
module.exports = defineConfig({
  testDir: '.', testMatch: 'deployment.spec.cjs', workers: 1, retries: 0,
  timeout: 240000, expect: { timeout: 30000 },
  outputDir: `test-results/${process.env.WEB_DEPLOYMENT_PUBLIC_ONLY ? 'production' : 'staged'}`,
  reporter: [['list'], ['html', { open: 'never', outputFolder: `playwright-report/${process.env.WEB_DEPLOYMENT_PUBLIC_ONLY ? 'production' : 'staged'}` }]],
  use: {
    viewport: { width: 1280, height: 720 },
    screenshot: 'only-on-failure',
    // Traces record request headers; never retain the staging protection secret.
    trace: process.env.WEB_DEPLOYMENT_BYPASS_SECRET ? 'off' : 'retain-on-failure',
    extraHTTPHeaders: process.env.WEB_DEPLOYMENT_BYPASS_SECRET ? {
      'x-vercel-protection-bypass': process.env.WEB_DEPLOYMENT_BYPASS_SECRET,
      'x-vercel-set-bypass-cookie': 'true',
    } : {},
    launchOptions: { args: process.platform === 'darwin' ? ['--use-angle=metal'] : ['--use-angle=swiftshader', '--enable-unsafe-swiftshader'] },
  },
});

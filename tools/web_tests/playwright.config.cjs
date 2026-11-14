const { defineConfig } = require('@playwright/test');
module.exports = defineConfig({
  testDir: '.', testMatch: '*.spec.cjs', fullyParallel: false, workers: 1,
  retries: 0, timeout: 180000, expect: { timeout: 30000 },
  reporter: [['list'], ['html', { open: 'never' }]],
  use: {
    viewport: { width: 1280, height: 720 },
    screenshot: 'only-on-failure', trace: 'retain-on-failure', video: process.env.WEB_RECORD ? 'on' : 'retain-on-failure',
    launchOptions: { args: process.platform === 'darwin' && !process.env.WEB_SOFTWARE ? ['--use-angle=metal'] : ['--use-angle=swiftshader', '--enable-unsafe-swiftshader'] },
  },
  projects: [{ name: process.env.WEB_BROWSER || 'chromium', use: { browserName: process.env.WEB_BROWSER || 'chromium' } }],
  webServer: [
    { command: 'python3 ../serve_web.py ../../build/web --port 8070', url: 'http://127.0.0.1:8070', reuseExistingServer: false },
    { command: 'python3 ../serve_web.py ../../build/web-diagnostics --port 8071', url: 'http://127.0.0.1:8071', reuseExistingServer: false },
  ],
});

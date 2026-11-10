// The editor in WebKit, the engine of elixir-desktop's macOS view, served
// by the app as a plain local web server (testing.md § End to end). Each
// test opens its own temp copy of a fixture with ?spec=.
import { defineConfig, devices } from '@playwright/test'

const port = 4011

export default defineConfig({
  testDir: '.',
  projects: [{ name: 'webkit', use: { ...devices['Desktop Safari'] } }],
  use: { baseURL: `http://127.0.0.1:${port}`, viewport: { width: 1600, height: 1000 } },
  webServer: {
    command: 'mix assets.build && mix phx.server',
    cwd: '..',
    env: { PORT: String(port) },
    url: `http://127.0.0.1:${port}`,
    // A server already on the port fails the run rather than being tested.
    reuseExistingServer: false,
    timeout: 180_000,
  },
})

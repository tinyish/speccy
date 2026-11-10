import Config

config :desktop, :backend, DesktopWebview.Backend
config :desktop, :menu_adapter, DesktopWebview.Menu.Adapter
config :desktop_webview, test_rpc: System.get_env("EDW_TEST_RPC") != nil

config :desktop_canvas, DesktopCanvas.Endpoint,
  adapter: Bandit.PhoenixAdapter,
  url: [host: "127.0.0.1", port: 4320],
  http: [ip: {127, 0, 0, 1}, port: 4320],
  server: true,
  check_origin: false,
  secret_key_base: String.duplicate("speccy", 11),
  live_view: [signing_salt: "speccyspike"],
  pubsub_server: DesktopCanvas.PubSub

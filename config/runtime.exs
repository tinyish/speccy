import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.

# The window runs only where there is a host to show it: in the release (the
# app), and in development with SPECCY_WINDOW=1, where the BEAM starts the host.
window =
  config_env() == :prod or (config_env() == :dev and System.get_env("SPECCY_WINDOW") == "1")

config :speccy, window: window

if window do
  config :desktop, :backend, DesktopWebview.Backend
  config :desktop, :menu_adapter, DesktopWebview.Menu.Adapter
else
  config :desktop, :backend, :browser
end

config :speccy, SpeccyWeb.Endpoint,
  http: [port: String.to_integer(System.get_env("PORT", "4000"))]

if config_env() == :dev do
  # Reload browser tabs when matching files change.
  config :speccy, SpeccyWeb.Endpoint,
    live_reload: [
      web_console_logger: true,
      patterns: [
        # Static assets, except user uploads
        ~r"priv/static/(?!uploads/).*\.(js|css|png|jpeg|jpg|gif|svg)$"E,
        # Router, Controllers, LiveViews and LiveComponents
        ~r"lib/speccy_web/router\.ex$"E,
        ~r"lib/speccy_web/(controllers|live|components)/.*\.(ex|heex)$"E
      ]
    ]
end

if config_env() == :prod do
  # The release is the app: on 127.0.0.1 only, at a port picked at launch
  # (`Desktop.Endpoint` finds it), with a secret of its own each launch.
  config :speccy, SpeccyWeb.Endpoint,
    url: [host: "127.0.0.1"],
    http: [ip: {127, 0, 0, 1}, port: 0],
    server: true,
    secret_key_base: Base.encode64(:crypto.strong_rand_bytes(48))
end

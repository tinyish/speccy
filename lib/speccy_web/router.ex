defmodule SpeccyWeb.Router do
  use SpeccyWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :window_key
    plug :fetch_live_flash
    plug :put_root_layout, html: {SpeccyWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  # In the window, a request needs the key its URL carries once per launch
  # (`?k=`), then holds it in its session: no other page on the machine gets in.
  defp window_key(conn, _),
    do: if(SpeccyWeb.Window.on?(), do: Desktop.Auth.call(conn), else: conn)

  scope "/", SpeccyWeb do
    pipe_through :browser

    live "/", EditorLive
  end

  # Pages for judging the wireframes by eye.
  if Application.compile_env(:speccy, :dev_routes) do
    scope "/dev", SpeccyWeb do
      pipe_through :browser

      get "/primitives", DevController, :primitives
      get "/frame", DevController, :frame
    end
  end

  # Other scopes may use custom stacks.
  # scope "/api", SpeccyWeb do
  #   pipe_through :api
  # end
end

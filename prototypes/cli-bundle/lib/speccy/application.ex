defmodule Speccy.Application do
  # The app: one window on a local page that lists every folder `speccy open` handed it.
  use Application

  @port 4310

  def start(_type, _args) do
    children = [
      {Bandit, plug: Speccy.Page, ip: {127, 0, 0, 1}, port: @port},
      Speccy.Opened,
      {Desktop.Window, app: :speccy, id: SpeccyWindow, title: "speccy spike", size: {600, 400},
       url: fn -> "http://127.0.0.1:#{@port}/" end}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: Speccy.Supervisor)
  end
end

defmodule Speccy.Opened do
  # Keeps the folders the app was asked to open: from its own argv and from second launches.
  use GenServer

  def start_link(_), do: GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  def list, do: GenServer.call(__MODULE__, :list)

  def init(_) do
    Desktop.Env.subscribe()
    {:ok, for(p <- [System.get_env("SPECCY_OPEN")], p, do: {:launch, p, now()})}
  end

  def handle_call(:list, _, opened), do: {:reply, opened, opened}
  def handle_info({tag, paths}, opened) when tag in [:open_file, :open_url],
    do: {:noreply, opened ++ Enum.map(paths, &{tag, &1, now()})}
  def handle_info(_, opened), do: {:noreply, opened}

  defp now, do: System.os_time(:millisecond)
end

defmodule Speccy.Page do
  use Plug.Router
  plug :match
  plug :dispatch

  get "/" do
    rows = for {how, path, t} <- Speccy.Opened.list(), do: "<li>#{t} #{how} #{path}</li>"
    send_resp(conn, 200, "<h1>speccy spike</h1><ul id=opened>#{rows}</ul><script>setTimeout(()=>location.reload(),1000)</script>")
  end

  get "/opened.json" do
    body = Jason.encode!(for {how, path, t} <- Speccy.Opened.list(), do: %{how: how, path: path, at: t})
    send_resp(conn, 200, body)
  end
end

defmodule SpeccyWeb.Menu do
  @moduledoc """
  The window's menu bar: File > Open… and File > Open Recent, the recent
  specs newest first. The Edit menu is the host's, and the host gives items
  no key equivalents: the page catches ⌘O (`decisions.md#shortcuts-in-page`).
  """
  use Desktop.Menu

  alias SpeccyWeb.{Recent, Window}

  @impl true
  def mount(menu), do: {:ok, assign(menu, recent: Recent.list())}

  @impl true
  def handle_event("open", menu) do
    Window.choose()
    {:noreply, menu}
  end

  def handle_event("recent " <> i, menu) do
    Window.open(Enum.at(menu.assigns.recent, String.to_integer(i)))
    {:noreply, menu}
  end

  @impl true
  # Sent by `Window.open/1` once a spec is recorded.
  def handle_info(:recent, menu), do: {:noreply, assign(menu, recent: Recent.list())}

  @impl true
  def render(assigns) do
    ~H"""
    <menubar>
      <menu label="File">
        <item onclick="open">Open…</item>
        <menu label="Open Recent">
          <item :for={{dir, i} <- Enum.with_index(@recent)} onclick={"recent #{i}"}>{dir}</item>
        </menu>
      </menu>
    </menubar>
    """
  end
end

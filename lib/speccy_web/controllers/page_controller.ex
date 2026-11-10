defmodule SpeccyWeb.PageController do
  use SpeccyWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end

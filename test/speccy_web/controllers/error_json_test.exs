defmodule SpeccyWeb.ErrorJSONTest do
  use SpeccyWeb.ConnCase, async: true

  test "renders 404" do
    assert SpeccyWeb.ErrorJSON.render("404.json", %{}) == %{errors: %{detail: "Not Found"}}
  end

  test "renders 500" do
    assert SpeccyWeb.ErrorJSON.render("500.json", %{}) ==
             %{errors: %{detail: "Internal Server Error"}}
  end
end

defmodule Speccy.Primitives.Container do
  @moduledoc false

  def interface do
    %{
      name: "container",
      about:
        "A box that lays out other components. It can be pressed as a whole (a card, a nav item, a tab) and carry a role: a landmark, a tab list or tab panel, a live region.",
      category: "layout",
      element:
        "div (role from role; role=button when pressable, link when it also has href; aria-current from current, aria-selected on a tab, aria-expanded with aria-controls when it controls another container)",
      props: [
        {"pressable", "bool"},
        {"href", "text"},
        {"role",
         [
           "none",
           "navigation",
           "toolbar",
           "tablist",
           "tab",
           "tabpanel",
           "alert",
           "status",
           "group",
           "region"
         ]},
        {"current", ["none", "page", "step"]},
        {"selected", "bool"},
        {"expanded", "bool"},
        {"controls", "text"}
      ],
      events: [{"press", nil}],
      states: [],
      defaults: %{
        "current" => "none",
        "expanded" => false,
        "pressable" => false,
        "role" => "none",
        "selected" => false
      },
      examples: [
        {"card", %{"pressable" => true}},
        {"nav item, current", %{"current" => "page", "pressable" => true}},
        {"tab, selected", %{"pressable" => true, "role" => "tab", "selected" => true}},
        {"navigation", %{"role" => "navigation"}},
        {"alert", %{"role" => "alert"}}
      ],
      children: true,
      slot: true,
      pressable: {:prop, "pressable"},
      aria: %{"controls" => "controls", "current" => "current", "role" => "role"}
    }
  end
end

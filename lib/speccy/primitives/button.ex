defmodule Speccy.Primitives.Button do
  @moduledoc false

  use Phoenix.Component

  @debug_heex_annotations false
  @debug_attributes false

  import Speccy.Draw, only: [text: 1, present?: 1, list: 1]
  alias Speccy.Draw

  def interface do
    %{
      name: "button",
      about:
        "A control the user presses to run an action. It can stay selected like a toggle, carry a menu of related actions, or be removed, so small buttons also cover tags, chips and badges.",
      category: "actions",
      element:
        "button (aria-pressed when selected; icon-only when it has no text, named by label; plus a menu button, aria-haspopup=menu, when it has options; plus a remove button when removable)",
      props: [
        {"text", "text"},
        {"label", "text"},
        {"leadingIcon", "icon"},
        {"trailingIcon", "icon"},
        {"size", ["sm", "md", "lg"]},
        {"selected", "bool"},
        {"disabled", "bool"},
        {"options", "text[]"},
        {"open", "bool"},
        {"removable", "bool"}
      ],
      events: [{"press", nil}, {"select", "text"}, {"remove", nil}],
      states: [
        {"selected",
         %{about: "Stays pressed, like a toggle that is on.", props: %{"selected" => true}}},
        {"disabled", %{about: "Can't be pressed.", props: %{"disabled" => true}}},
        {"open",
         %{
           about: "Its menu of related actions is open.",
           props: %{
             "open" => true,
             "options" => ["Save as draft", "Save and close", "Save a copy"]
           }
         }}
      ],
      defaults: %{
        "disabled" => false,
        "open" => false,
        "removable" => false,
        "selected" => false,
        "size" => "md"
      },
      examples: [
        {"basic", %{"text" => "Save changes"}},
        {"small", %{"size" => "sm", "text" => "Save"}},
        {"large", %{"size" => "lg", "text" => "Save changes"}},
        {"with icons",
         %{
           "leadingIcon" => "material/save",
           "text" => "Save changes",
           "trailingIcon" => "material/expand_more"
         }},
        {"icon only", %{"label" => "Favourite", "leadingIcon" => "material/favorite"}},
        {"icon only selected",
         %{"label" => "Favourite", "leadingIcon" => "material/favorite", "selected" => true}},
        {"removable tag", %{"removable" => true, "size" => "sm", "text" => "Design"}}
      ],
      children: false,
      slot: false,
      pressable: true,
      aria: %{}
    }
  end

  def draw(assigns) do
    p = assigns.props
    options = list(p["options"])
    size = if p["size"] in ~w(sm lg), do: "wf-#{p["size"]}"

    assigns =
      assign(assigns,
        options: options,
        size: size,
        group: options != [] or p["removable"] == true
      )

    ~H"""
    <div :if={@group} class="wf-group wf-anchor" role="group" style={@style} {@data}>
      <.face props={@props} icons={@icons} size={@size} />
      <button
        :if={@options != []}
        type="button"
        class={["wf-btn wf-square", @size, @props["open"] == true && "wf-on"]}
        aria-haspopup="menu"
        aria-expanded={to_string(@props["open"] == true)}
        aria-label="More options"
        disabled={@props["disabled"] == true}
      >
        ▾
      </button>
      <button
        :if={@props["removable"] == true}
        type="button"
        class={["wf-btn wf-square", @size]}
        aria-label="Remove"
        disabled={@props["disabled"] == true}
      >
        ×
      </button>
      <ul :if={@options != []} role="menu" class="wf-popup" hidden={@props["open"] != true}>
        <li :for={option <- @options} role="menuitem" class="wf-option">{text(option)}</li>
      </ul>
    </div>
    <.face :if={!@group} props={@props} icons={@icons} size={@size} style={@style} data={@data} />
    """
  end

  attr :props, :map, required: true
  attr :icons, :map, required: true
  attr :size, :string, default: nil
  attr :style, :string, default: nil
  attr :data, :map, default: %{}

  defp face(assigns) do
    ~H"""
    <button
      type="button"
      class={[
        "wf-btn",
        @size,
        !present?(@props["text"]) && "wf-square",
        @props["selected"] == true && "wf-on",
        @props["disabled"] == true && "wf-off"
      ]}
      aria-pressed={@props["selected"] == true && "true"}
      aria-label={present?(@props["label"]) && text(@props["label"])}
      disabled={@props["disabled"] == true}
      style={@style}
      {@data}
    >
      <Draw.icon :if={present?(@props["leadingIcon"])} ref={@props["leadingIcon"]} icons={@icons} />
      <span :if={present?(@props["text"])}>{text(@props["text"])}</span>
      <Draw.icon :if={present?(@props["trailingIcon"])} ref={@props["trailingIcon"]} icons={@icons} />
    </button>
    """
  end
end

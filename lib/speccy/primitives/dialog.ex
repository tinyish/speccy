defmodule Speccy.Primitives.Dialog do
  @moduledoc false

  use Phoenix.Component

  @debug_heex_annotations false
  @debug_attributes false

  import Speccy.Draw, only: [text: 1, present?: 1]

  def interface do
    %{
      name: "dialog",
      about:
        "A window over the page, centred or sliding in from an edge, that asks the user to read, decide or fill something in; modal ones block the page behind a backdrop.",
      category: "overlays",
      element:
        "dialog (modal, with a backdrop) or a non-modal panel; on an edge unless placement is center",
      props: [
        {"open", "bool"},
        {"title", "text"},
        {"text", "text"},
        {"placement", ["center", "left", "right", "bottom"]},
        {"modal", "bool"}
      ],
      events: [{"close", nil}],
      states: [{"open", %{about: "Shown over the page.", props: %{"open" => true}}}],
      defaults: %{"modal" => true, "open" => false, "placement" => "center"},
      examples: [
        {"basic",
         %{
           "text" => "This removes the project and its specs for everyone. You can't undo it.",
           "title" => "Delete project?"
         }}
      ],
      children: true,
      slot: true,
      pressable: false,
      aria: %{}
    }
  end

  def draw(assigns) do
    p = assigns.props
    placement = if p["placement"] in ~w(left right bottom), do: p["placement"], else: "center"
    assigns = assign(assigns, placement: placement)

    ~H"""
    <div
      role="dialog"
      aria-modal={@props["modal"] == true && "true"}
      aria-label={text(@props["title"])}
      class={["wf-surface wf-dialog", "wf-at-#{@placement}", @props["modal"] == true && "wf-modal"]}
      hidden={@props["open"] != true}
      style={@item}
      {@data}
    >
      <div class="wf-heading">
        <span class="wf-strong">{text(@props["title"])}</span>
        <button type="button" aria-label="Close">×</button>
      </div>
      <p :if={present?(@props["text"])}>{text(@props["text"])}</p>
      <div style={@box}>{render_slot(@inner_block)}</div>
    </div>
    """
  end
end

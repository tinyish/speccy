defmodule Speccy.Primitives.FileUpload do
  @moduledoc false

  use Phoenix.Component

  @debug_heex_annotations false
  @debug_attributes false

  import Speccy.Draw, only: [text: 1, present?: 1, list: 1]

  def interface do
    %{
      name: "file-upload",
      about:
        "A drop zone the user drags files onto or browses from, listing queued files with progress.",
      category: "inputs",
      element: "input type=file (with drop zone)",
      props: [{"accept", "text"}, {"multiple", "bool"}, {"files", "text[]"}, {"disabled", "bool"}],
      events: [{"change", "text[]"}, {"remove", "text"}],
      states: [],
      defaults: %{"disabled" => false, "multiple" => false},
      examples: [
        {"basic",
         %{
           "accept" => ".pdf, .png, .jpg",
           "files" => ["brief.pdf", "hero.png", "moodboard.jpg"],
           "multiple" => true
         }}
      ],
      children: false,
      slot: false,
      pressable: true,
      aria: %{}
    }
  end

  def draw(assigns) do
    assigns = assign(assigns, files: list(assigns.props["files"]))

    ~H"""
    <div class={["wf-control", @props["disabled"] == true && "wf-off"]} style={@style} {@data}>
      <label class="wf-drop">
        <span aria-hidden="true">↑</span>
        <span>
          Drop {if @props["multiple"] == true, do: "files", else: "a file"} here or
          <span class="wf-link">browse</span>
        </span>
        <span :if={present?(@props["accept"])} class="wf-hint">{text(@props["accept"])}</span>
        <input
          type="file"
          hidden
          accept={text(@props["accept"])}
          multiple={@props["multiple"] == true}
          disabled={@props["disabled"] == true}
        />
      </label>
      <ul :if={@files != []} class="wf-files">
        <li :for={file <- @files}>
          <span class="wf-grow">{text(file)}</span>
          <button type="button" aria-label={"Remove #{text(file)}"}>×</button>
        </li>
      </ul>
    </div>
    """
  end
end

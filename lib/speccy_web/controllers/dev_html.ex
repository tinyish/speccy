defmodule SpeccyWeb.DevHTML do
  @moduledoc "The development pages of `SpeccyWeb.DevController`."
  use SpeccyWeb, :html

  alias Speccy.Draw

  def primitives(assigns) do
    ~H"""
    <style>
      <%= Phoenix.HTML.raw(Draw.css()) %>
    </style>
    <main class="p-8 space-y-10 bg-base-200 min-h-screen">
      <h1 class="text-2xl font-semibold">Primitives</h1>
      <section :for={{category, primitives} <- @categories} class="space-y-6">
        <h2 class="text-lg font-semibold uppercase tracking-wide opacity-60">{category}</h2>
        <div :for={{name, cells} <- primitives} id={name} class="space-y-2">
          <h3 class="font-mono font-semibold">{name}</h3>
          <div class="flex flex-wrap items-start gap-6">
            <figure :for={{caption, tree, size} <- cells} class="space-y-1 pb-32">
              <div class="w-fit border border-base-300">
                <Draw.frame tree={tree} size={size} />
              </div>
              <figcaption class="text-xs opacity-70">{caption}</figcaption>
            </figure>
          </div>
        </div>
      </section>
    </main>
    """
  end

  def frame(assigns) do
    ~H"""
    <style>
      <%= Phoenix.HTML.raw(Draw.css()) %>
    </style>
    <main class="p-8 space-y-6 bg-base-200 min-h-screen">
      <nav class="flex flex-wrap gap-2 text-sm">
        <.link
          :for={path <- @items}
          href={"/dev/frame?" <> URI.encode_query(spec: @spec_name, file: path)}
          class={["btn btn-xs", path == @path && "btn-primary"]}
        >
          {path}
        </.link>
      </nav>
      <div class="flex flex-wrap items-start gap-10">
        <figure :for={{name, tree} <- @frames} class="space-y-2 shrink-0">
          <figcaption class="text-sm font-semibold">{name}</figcaption>
          <div class="shadow">
            <Draw.frame tree={tree} icons={@icons} size={@size} />
          </div>
        </figure>
      </div>
    </main>
    """
  end
end

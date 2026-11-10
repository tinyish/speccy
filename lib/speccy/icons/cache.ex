defmodule Speccy.Icons.Cache do
  @moduledoc """
  The icon fetch (`conventions.md#pure-core`): an icon's SVG, from the
  loaded spec for its own sets, or from the per-user cache for a library's,
  kept at `<dir>/<library>/<version>/<name>.<style>.svg` and fetched into it
  from the library's pinned version. Whatever it hands back passes
  `Speccy.Icons.safe/1`, since drawing inlines it.
  """

  alias Speccy.Icons

  @doc "The per-user cache."
  def dir, do: Path.expand("~/.speccy/icons")

  @doc "The SVG for a reference, or `:missing` when it doesn't resolve, isn't cached or isn't safe."
  def svg(ref, spec, cache_dir \\ dir()) do
    svg =
      case Icons.resolve(ref, spec.icons) do
        {:ok, {set, name, nil}} ->
          spec.svgs["assets/icons/#{set}/#{name}.svg"]

        {:ok, {library, name, style}} ->
          with {:ok, svg} <- File.read(path(cache_dir, library, name, style)), do: svg

        _ ->
          nil
      end

    if is_binary(svg) and Icons.safe(svg) == :ok, do: svg, else: :missing
  end

  @doc """
  Fetches a library icon into the cache: `:ok` once it is there, or why
  not. One fetch at a time per icon; a second caller waits for the first
  and finds it cached.
  """
  def fetch(ref, cache_dir \\ dir()) do
    with {:ok, {library, name, style}} <- Icons.resolve(ref, %{}) do
      path = path(cache_dir, library, name, style)
      url = String.replace(Icons.library(library)["svg"][style], "{name}", name)

      :global.trans({{__MODULE__, path}, self()}, fn ->
        if File.exists?(path), do: :ok, else: download(url, path)
      end)
    end
  end

  defp download(url, path) do
    options = [url: url, decode_body: false] ++ Application.get_env(:speccy, __MODULE__, [])

    with {:ok, %{status: 200, body: svg}} <- Req.get(options),
         :ok <- safe(svg),
         :ok <- File.mkdir_p(Path.dirname(path)),
         # Written aside and renamed, so a reader never finds half a file.
         tmp = "#{path}.#{System.unique_integer([:positive])}.tmp",
         :ok <- File.write(tmp, svg) do
      File.rename(tmp, path)
    else
      {:ok, %{status: status}} -> {:error, {:status, status}}
      {:error, _} = error -> error
    end
  end

  defp safe(svg) do
    with {:error, code, why} <- Icons.safe(svg), do: {:error, {code, why}}
  end

  defp path(dir, library, name, style),
    do: Path.join([dir, library, Icons.library(library)["version"], "#{name}.#{style}.svg"])
end

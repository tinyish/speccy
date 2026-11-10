defmodule SpeccyWeb.Recent do
  @moduledoc """
  The recent specs: `~/.speccy/recent.json`, a JSON list of absolute spec
  folders, newest first, at most ten. A folder that no longer holds a spec
  is dropped when read.
  """

  alias Speccy.Format

  @max 10

  defp path, do: Path.expand(Application.get_env(:speccy, :recent, "~/.speccy/recent.json"))

  @doc "The recent spec folders, newest first."
  def list do
    with {:ok, json} <- File.read(path()),
         {:ok, dirs} when is_list(dirs) <- Jason.decode(json) do
      Enum.filter(dirs, &(is_binary(&1) and Format.find(&1) == {:ok, &1}))
    else
      _ -> []
    end
  end

  @doc "Puts the spec folder `dir` (absolute) first."
  def add(dir) do
    File.mkdir_p!(Path.dirname(path()))
    File.write!(path(), Jason.encode!(Enum.take([dir | List.delete(list(), dir)], @max)))
  end
end

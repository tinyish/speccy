defmodule Speccy.Primitives do
  @moduledoc """
  The registry of the 25 primitives built into speccy, by category. Each is
  a module whose `interface/0` describes it as plain data: name, about,
  category, element, props (ordered `{name, type}`), events, states (ordered
  `{name, %{about, props}}`), defaults (what an unset prop means, never
  sample content), examples (sample content to draw it with), and the facts
  the checker's rules read: `children` (holds children), `slot` (can be a
  component's named slot), `pressable` (`true`,
  `false` or `{:prop, name}`, pressable when that prop is truthy: true or a
  non-empty string) and `aria` (ARIA attribute → the prop that sets it, only
  for the attributes the composition rules read).
  """

  @modules [
    Speccy.Primitives.Button,
    Speccy.Primitives.DatePicker,
    Speccy.Primitives.FileUpload,
    Speccy.Primitives.Form,
    Speccy.Primitives.Input,
    Speccy.Primitives.OtpInput,
    Speccy.Primitives.Slider,
    Speccy.Primitives.Checkbox,
    Speccy.Primitives.RadioGroup,
    Speccy.Primitives.Select,
    Speccy.Primitives.Link,
    Speccy.Primitives.TreeView,
    Speccy.Primitives.Progress,
    Speccy.Primitives.Toast,
    Speccy.Primitives.Dialog,
    Speccy.Primitives.Menu,
    Speccy.Primitives.Popover,
    Speccy.Primitives.List,
    Speccy.Primitives.Table,
    Speccy.Primitives.Text,
    Speccy.Primitives.Container,
    Speccy.Primitives.Divider,
    Speccy.Primitives.Icon,
    Speccy.Primitives.Image,
    Speccy.Primitives.Video
  ]

  @doc "Every primitive's module."
  def all, do: @modules

  @by_name Map.new(@modules, &{&1.interface().name, &1})

  @doc "The module of the primitive called `name`, or nil."
  def get(name), do: @by_name[name]

  @fields ~w(name about category element props events states defaults examples children slot pressable aria)a

  @doc """
  An interface as JSON-able data, for `speccy explain` and tests: its
  fields in the order above, ordered lists as ordered objects, `{:prop, name}`
  as `{"prop": name}`.
  """
  def json(interface) do
    object(for field <- @fields, do: {Atom.to_string(field), json(field, interface[field])})
  end

  defp json(field, list) when field in [:props, :events, :examples], do: object(list)

  defp json(:states, states) do
    object(
      for {name, state} <- states, do: {name, object(about: state.about, props: state.props)}
    )
  end

  defp json(:pressable, {:prop, name}), do: %{"prop" => name}
  defp json(_field, value), do: value

  defp object(pairs),
    do: %Jason.OrderedObject{values: Enum.map(pairs, fn {k, v} -> {to_string(k), v} end)}
end

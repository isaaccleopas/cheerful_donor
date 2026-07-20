defmodule CheerfulDonor.EventSerializer do
  @behaviour EventStore.Serializer

  @impl true
  def serialize(%_{} = term) do
    term
    |> Map.from_struct()
    |> Map.put(:__struct__, to_string(term.__struct__))
    |> Jason.encode!()
  end

  def serialize(term), do: Jason.encode!(term)

  @impl true
  def deserialize(data, config) do
    parsed = Jason.decode!(data)

    case Keyword.get(config, :type) do
      type when type in [:metadata, "metadata", nil] ->
        parsed

      _event_type ->
        case Map.pop(parsed, "__struct__") do
          {nil, map} ->
            map

          {name, fields} ->
            module = String.to_existing_atom(name)
            struct(module, atomize_keys(fields, module))
        end
    end
  end

  defp atomize_keys(map, module) do
    known =
      module.__struct__()
      |> Map.from_struct()
      |> Map.new(fn {k, _v} -> {Atom.to_string(k), k} end)

    Map.new(map, fn
      {k, v} when is_binary(k) ->
        case Map.fetch(known, k) do
          {:ok, atom} -> {atom, v}
          :error -> {k, v}
        end

      {k, v} ->
        {k, v}
    end)
  end
end

defmodule Ravix.Documents.Metadata do
  @spec build_default_metadata(nil | map) :: {} | map
  def build_default_metadata(entity) when entity == nil, do: {}

  def build_default_metadata(entity) do
    case collection_name(entity) do
      nil ->
        nil

      collection_name ->
        metadata = existing_metadata(entity)
        Map.put(metadata, :"@collection", collection_name)
    end
  end

  @spec add_metadata(any, any) ::
          {:error, :invalid_entity | :struct_without_metadata} | {:ok, map()}
  def add_metadata(entity, nil), do: {:ok, entity}

  def add_metadata(entity, metadata) when is_map(metadata),
    do: {:ok, Map.put(entity, :"@metadata", metadata)}

  def add_metadata(entity, _) when is_struct(entity) and not is_map_key(entity, :"@metadata"),
    do: {:error, :struct_without_metadata}

  def add_metadata(entity, metadata) when is_struct(entity),
    do: {:ok, put_in(entity[:"@metadata"], metadata)}

  def add_metadata(_, _), do: {:error, :invalid_entity}

  defp existing_metadata(entity) when not is_map_key(entity, :"@metadata"), do: %{}

  defp existing_metadata(entity), do: entity[:"@metadata"]

  defp collection_name(entity) when not is_struct(entity), do: nil

  defp collection_name(entity),
    do: entity.__struct__ |> Module.split() |> Enum.reverse() |> Enum.at(0)
end

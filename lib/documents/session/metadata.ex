defmodule Ravix.Documents.Metadata do
  @moduledoc """
  Functions related to document metadata management
  """

  @doc """
  Builds the metadata for the informed document

  ## Parameters
  - entity: The document to build the metadata

  ## Returns
  - the metadata for the entity
  """
  @spec build_default_metadata(map()) :: nil | %{:"@collection" => any, optional(any) => any}
  def build_default_metadata(entity) do
    case collection_name(entity) do
      nil ->
        nil

      collection_name ->
        metadata = existing_metadata(entity)
        Map.put(metadata, :"@collection", collection_name)
    end
  end

  @doc """
  Adds the metadata to the entity

  ## Parameters
  - entity: the document
  - metadata: the metadata to add to the document
  """
  @spec add_metadata(map(), nil | map) :: map()
  def add_metadata(entity, nil), do: entity

  def add_metadata(entity, metadata) when is_map(metadata),
    do: Map.put(entity, :"@metadata", metadata)

  defp existing_metadata(entity) when not is_map_key(entity, :"@metadata"), do: %{}

  defp existing_metadata(entity), do: entity[:"@metadata"]

  defp collection_name(entity) when not is_struct(entity), do: nil

  defp collection_name(entity),
    do:
      entity.__struct__
      |> Module.split()
      |> Enum.reverse()
      |> Enum.at(0)
end

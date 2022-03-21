defmodule Ravix.Documents.Conventions do
  defstruct max_number_of_requests_per_session: 30,
            max_ids_to_catch: 32,
            timeout: 30,
            use_optimistic_concurrency: false,
            max_length_of_query_using_get_url: 1024 + 512,
            identity_parts_separator: "/",
            disable_topology_update: false

  use Vex.Struct

  alias Ravix.Documents.Conventions

  @type t :: %Conventions{
          max_number_of_requests_per_session: non_neg_integer(),
          max_ids_to_catch: non_neg_integer(),
          timeout: non_neg_integer(),
          use_optimistic_concurrency: boolean(),
          max_length_of_query_using_get_url: non_neg_integer(),
          identity_parts_separator: String.t(),
          disable_topology_update: boolean()
        }

  @spec build_default_metadata(nil | map) :: {} | map
  def build_default_metadata(entity) when entity == nil, do: {}

  def build_default_metadata(entity) do
    metadata = existing_metadata(entity)
    Map.put(metadata, "@collection", collection_name(entity))
  end

  defp existing_metadata(entity) when not is_map_key(entity, "@metadata"), do: %{}

  defp existing_metadata(entity), do: entity["@metadata"]

  defp collection_name(entity) when not is_map_key(entity, "__struct__"), do: ""

  defp collection_name(entity), do: entity.__struct__
end

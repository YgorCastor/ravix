defmodule Ravix.Documents.Store.State do
  defstruct urls: [],
            default_database: nil,
            document_conventions: nil

  alias Ravix.Documents.Store.{State, Configs}
  alias Ravix.Documents.Conventions

  @type t :: %State{
          urls: list(String.t()),
          default_database: String.t(),
          document_conventions: Conventions.t()
        }

  @spec from_map(Configs.t()) :: State.t()
  def from_map(%Configs{} = ravix_configs) do
    %State{
      urls: ravix_configs.urls,
      default_database: ravix_configs.database,
      document_conventions: %Conventions{
        max_number_of_requests_per_session:
          ravix_configs.document_conventions.max_number_of_requests_per_session,
        max_ids_to_catch: ravix_configs.document_conventions.max_ids_to_catch,
        timeout: ravix_configs.document_conventions.timeout,
        use_optimistic_concurrency: ravix_configs.document_conventions.use_optimistic_concurrency,
        max_length_of_query_using_get_url:
          ravix_configs.document_conventions.max_length_of_query_using_get_url,
        identity_parts_separator: ravix_configs.document_conventions.identity_parts_separator,
        disable_topology_update: ravix_configs.document_conventions.disable_topology_update
      }
    }
  end
end

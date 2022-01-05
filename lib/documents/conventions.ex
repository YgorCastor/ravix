defmodule Ravix.Documents.Conventions do
  defstruct max_number_of_requests_per_session: 30,
            max_ids_to_catch: 32,
            timeout: 30,
            use_optimistic_concurrency: false,
            max_length_of_query_using_get_url: 1024 + 512,
            identity_parts_separator: "/",
            disable_topology_update: false

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
end

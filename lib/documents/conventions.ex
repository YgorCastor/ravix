defmodule Ravix.Documents.Conventions do
  @moduledoc """
  Document conventions structure

  ## Fields
  - max_number_of_requests_per_session: How many requests can be done in a single session
  - max_ids_to_catch: Maximum amount of ids that can be loaded
  - timeout: How much time until an api call times out
  - use_optimistic_concurrency: If optimistic concurrency should be used
  - max_length_of_query_using_get_url: Maximum lenght of an api call url
  - session_idle_ttl: How much time a session can live without interaction
  - disable_topology_update: if true, no automatic topology updates will be executed
  """
  defstruct max_number_of_requests_per_session: 30,
            max_ids_to_catch: 32,
            timeout: 30,
            use_optimistic_concurrency: false,
            max_length_of_query_using_get_url: 1024 + 512,
            identity_parts_separator: "/",
            session_idle_ttl: 30,
            disable_topology_update: false

  alias Ravix.Documents.Conventions

  @type t :: %Conventions{
          max_number_of_requests_per_session: non_neg_integer(),
          max_ids_to_catch: non_neg_integer(),
          timeout: non_neg_integer(),
          use_optimistic_concurrency: boolean(),
          max_length_of_query_using_get_url: non_neg_integer(),
          identity_parts_separator: String.t(),
          session_idle_ttl: non_neg_integer(),
          disable_topology_update: boolean()
        }
end

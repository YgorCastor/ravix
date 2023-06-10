defmodule Ravix.Documents.Caching do
  @moduledoc """

  ## Fields
  - use_agressive_cache: Sends the 'If-None-Match' headers on query, if the result is cached locally and did not change, the query will return a 304 and not the actual results
  - cache_duration: How long should the cache be kept on the client side (in seconds)
  - cache: The nebulex cache module to use
  """
  defstruct enable_agressive_cache: false, cache_duration: nil, cache: nil

  alias __MODULE__

  @type t :: %Caching{
          enable_agressive_cache: boolean(),
          cache_duration: non_neg_integer(),
          cache: module()
        }
end

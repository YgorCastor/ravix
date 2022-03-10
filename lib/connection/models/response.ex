defmodule Ravix.Connection.Response do
  defstruct [
    :status,
    :data,
    :headers
  ]

  alias Ravix.Connection.Response

  @type t :: %Response{
          status: non_neg_integer(),
          data: map(),
          headers: list(map())
        }
end

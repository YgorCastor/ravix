defmodule Ravix.RQL.Tokens.Limit do
  @moduledoc false
  defstruct [
    :token,
    :skip,
    :next
  ]

  alias Ravix.RQL.Tokens.Limit

  @type t :: %Limit{
          token: atom(),
          skip: non_neg_integer(),
          next: non_neg_integer()
        }

  @spec limit(non_neg_integer(), non_neg_integer()) :: Limit.t()
  def limit(skip, next) do
    %Limit{
      token: :limit,
      skip: skip,
      next: next
    }
  end
end

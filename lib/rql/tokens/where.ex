defmodule Ravix.RQL.Tokens.Where do
  @moduledoc false
  defstruct [
    :token,
    :condition
  ]

  alias Ravix.RQL.Tokens.Where
  alias Ravix.RQL.Tokens.Condition

  @type t :: %Where{
          token: atom(),
          condition: Condition.t()
        }

  @spec condition(Condition.t()) :: Where.t()
  def condition(%Condition{} = condition) do
    %Where{
      token: :where,
      condition: condition
    }
  end
end

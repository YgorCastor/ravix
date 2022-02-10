defmodule Ravix.RQL.Tokens.Where do
  defstruct [
    :token,
    :condition
  ]

  alias Ravix.RQL.Tokens.Where
  alias Ravix.RQL.Tokens.Condition

  def condition(%Condition{} = condition) do
    %Where{
      token: :where,
      condition: condition
    }
  end
end

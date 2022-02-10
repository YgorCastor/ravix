defmodule Ravix.RQL.Tokens.Or do
  defstruct [
    :token,
    :condition
  ]

  alias Ravix.RQL.Tokens.{Or, Condition}

  def condition(%Condition{} = condition) do
    %Or{
      token: :or,
      condition: condition
    }
  end
end

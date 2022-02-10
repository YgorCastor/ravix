defmodule Ravix.RQL.Tokens.And do
  defstruct [
    :token,
    :condition
  ]

  alias Ravix.RQL.Tokens.{Condition, And}

  def condition(%Condition{} = condition) do
    %And{
      token: :and,
      condition: condition
    }
  end
end

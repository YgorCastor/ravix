defmodule Ravix.RQL.Tokens.Or do
  @moduledoc false
  defstruct [
    :token,
    :condition
  ]

  alias Ravix.RQL.Tokens.{Or, Condition}

  @type t :: %Or{
          token: atom(),
          condition: Condition.t()
        }

  @spec condition(Condition.t()) :: Or.t()
  def condition(%Condition{} = condition) do
    %Or{
      token: :or,
      condition: condition
    }
  end
end

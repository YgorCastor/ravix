defmodule Ravix.RQL.Tokens.And do
  @moduledoc false
  defstruct [
    :token,
    :condition
  ]

  alias Ravix.RQL.Tokens.{Condition, And}

  @type t :: %And{
          token: atom(),
          condition: Condition.t()
        }

  @spec condition(Condition.t()) :: And.t()
  def condition(%Condition{} = condition) do
    %And{
      token: :and,
      condition: condition
    }
  end
end

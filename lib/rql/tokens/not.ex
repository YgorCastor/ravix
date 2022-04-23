defmodule Ravix.RQL.Tokens.Not do
  @moduledoc false
  defstruct [
    :token,
    :condition
  ]

  alias Ravix.RQL.Tokens.{And, Not, Or}

  @type t :: %Not{
          token: atom(),
          condition: And.t() | Or.t()
        }

  @spec condition(And.t() | Or.t()) :: Not.t()
  def condition(condition) do
    %Not{
      token: :not,
      condition: condition
    }
  end
end

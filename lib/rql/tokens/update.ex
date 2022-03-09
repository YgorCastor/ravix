defmodule Ravix.RQL.Tokens.Update do
  defstruct [
    :token,
    :fields
  ]

  alias Ravix.RQL.Tokens.Update

  @type t :: %Update{
          token: atom(),
          fields: map()
        }

  def update(fields) do
    %Update{
      token: :update,
      fields: fields
    }
  end
end

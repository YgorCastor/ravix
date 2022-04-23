defmodule Ravix.RQL.Tokens.Group do
  @moduledoc false
  defstruct [
    :token,
    :fields
  ]

  alias Ravix.RQL.Tokens.Group

  @type t :: %Group{
          token: atom(),
          fields: list(String.t())
        }

  @spec by(String.t() | [String.t()]) :: Group.t()
  def by(fields) when is_list(fields) do
    %Group{
      token: :group_by,
      fields: fields
    }
  end

  def by(field) do
    %Group{
      token: :group_by,
      fields: [field]
    }
  end
end

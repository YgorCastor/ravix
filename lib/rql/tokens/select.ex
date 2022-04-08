defmodule Ravix.RQL.Tokens.Select do
  defstruct [
    :token,
    :fields
  ]

  alias Ravix.RQL.Tokens.Select

  @type t :: %Select{
          token: atom(),
          fields: list(String.t())
        }

  @spec fields(String.t() | list(String.t())) :: Ravix.RQL.Tokens.Select.t()
  def fields(fields) when is_list(fields) do
    %Select{
      token: :select,
      fields: fields
    }
  end

  def fields(field) do
    %Select{
      token: :select,
      fields: [field]
    }
  end
end

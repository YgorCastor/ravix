defmodule Ravix.RQL.Tokens.Select do
  defstruct [
    :token,
    :fields
  ]

  alias Ravix.RQL.Tokens.Select

  @type field_name :: String.t()
  @type field_alias :: String.t()
  @type allowed_select_params ::
          list(field_name() | {field_name(), field_alias()})
          | field_name()
          | {field_name(), field_alias()}

  @type t :: %Select{
          token: atom(),
          fields: list(field_name() | {field_name(), field_alias()})
        }

  @spec fields(allowed_select_params()) :: Select.t()
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

  @spec function(Keyword.t()) :: Select.t()
  def function(to) when is_list(to) do
    %Select{
      token: :select_function,
      fields: to
    }
  end
end

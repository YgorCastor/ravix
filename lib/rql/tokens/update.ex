defmodule Ravix.RQL.Tokens.Update do
  defstruct token: :update,
            fields: []

  alias Ravix.RQL.Tokens.Update

  @type t :: %Update{
          token: atom(),
          fields: list(map())
        }

  @spec fields(list(map())) :: Update.t()
  def fields(fields) do
    %Update{
      token: :update,
      fields: fields
    }
  end

  @spec set(Update.t(), String.t(), any) :: Ravix.RQL.Tokens.Update.t()
  def set(update, field, value) do
    %Update{
      update
      | fields: update.fields ++ [%{name: field, value: value, operation: :set}]
    }
  end

  @spec inc(Update.t(), String.t(), any) :: Ravix.RQL.Tokens.Update.t()
  def inc(update, field, value) do
    %Update{
      update
      | fields: update.fields ++ [%{name: field, value: value, operation: :inc}]
    }
  end

  @spec dec(Update.t(), String.t(), any) :: Ravix.RQL.Tokens.Update.t()
  def dec(update, field, value) do
    %Update{
      update
      | fields: update.fields ++ [%{name: field, value: value, operation: :dec}]
    }
  end
end

defmodule Ravix.RQL.Tokens.Update do
  @moduledoc """
  RQL Update tokens
  """
  defstruct token: :update,
            fields: []

  alias Ravix.RQL.Tokens.Update

  @type t :: %Update{
          token: atom(),
          fields: list(map())
        }

  @doc """
  Creates a new "set" update operation

  Returns a `Ravix.RQL.Tokens.Update`

  ## Examples
      iex> import alias Ravix.RQL.Tokens.Update
      iex> set("field1", 10) |> set("field2", "a")
  """
  @spec set(Update.t(), atom() | String.t(), any) :: Ravix.RQL.Tokens.Update.t()
  def set(update \\ %Update{}, field, value) do
    %Update{
      update
      | fields: update.fields ++ [%{name: field, value: value, operation: :set}]
    }
  end

  @doc """
  Creates a new "increment" update operation

  Returns a `Ravix.RQL.Tokens.Update`

  ## Examples
      iex> import alias Ravix.RQL.Tokens.Update
      iex> inc("field1", 10)
  """
  @spec inc(Update.t(), atom() | String.t(), number()) :: Ravix.RQL.Tokens.Update.t()
  def inc(update \\ %Update{}, field, value) when is_number(value) do
    %Update{
      update
      | fields: update.fields ++ [%{name: field, value: value, operation: :inc}]
    }
  end

  @doc """
  Creates a new "decrement" update operation

  Returns a `Ravix.RQL.Tokens.Update`

  ## Examples
      iex> import alias Ravix.RQL.Tokens.Update
      iex> dec("field1", 10)
  """
  @spec dec(Update.t(), atom() | String.t(), number()) :: Ravix.RQL.Tokens.Update.t()
  def dec(update \\ %Update{}, field, value) when is_number(value) do
    %Update{
      update
      | fields: update.fields ++ [%{name: field, value: value, operation: :dec}]
    }
  end
end

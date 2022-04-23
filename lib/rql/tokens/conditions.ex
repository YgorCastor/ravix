defmodule Ravix.RQL.Tokens.Condition do
  @moduledoc """
  Supported RQL Conditions
  """
  defstruct [
    :token,
    :field,
    :params
  ]

  alias Ravix.RQL.Tokens.Condition

  @type t :: %Condition{
          token: atom(),
          field: String.t() | Condition.t(),
          params: list()
        }

  @doc """
  Greater than condition

  Returns a `Ravix.RQL.Tokens.Condition`

  ## Examples
      iex> import Ravix.RQL.Tokens.Condition
      iex> greater_than("field", 10)
  """
  @spec greater_than(atom() | String.t(), number()) :: Condition.t()
  def greater_than(field_name, value) do
    %Condition{
      token: :greater_than,
      field: field_name,
      params: [value]
    }
  end

  @doc """
  Greater than or equal to condition

  Returns a `Ravix.RQL.Tokens.Condition`

  ## Examples
      iex> import Ravix.RQL.Tokens.Condition
      iex> greater_than_or_equal_to("field", 10)
  """
  @spec greater_than_or_equal_to(atom() | String.t(), number()) :: Condition.t()
  def greater_than_or_equal_to(field_name, value) do
    %Condition{
      token: :greater_than_or_eq,
      field: field_name,
      params: [value]
    }
  end

  @doc """
  Lower than condition

  Returns a `Ravix.RQL.Tokens.Condition`

  ## Examples
      iex> import Ravix.RQL.Tokens.Condition
      iex> lower_than("field", 10)
  """
  @spec lower_than(atom() | String.t(), number()) :: Condition.t()
  def lower_than(field_name, value) do
    %Condition{
      token: :lower_than,
      field: field_name,
      params: [value]
    }
  end

  @doc """
  Lower than or equal to condition

  Returns a `Ravix.RQL.Tokens.Condition`

  ## Examples
      iex> import Ravix.RQL.Tokens.Condition
      iex> lower_than_or_equal_to("field", 10)
  """
  @spec lower_than_or_equal_to(atom() | String.t(), number()) :: Condition.t()
  def lower_than_or_equal_to(field_name, value) do
    %Condition{
      token: :lower_than_or_eq,
      field: field_name,
      params: [value]
    }
  end

  @doc """
  Equal to condition

  Returns a `Ravix.RQL.Tokens.Condition`

  ## Examples
      iex> import Ravix.RQL.Tokens.Condition
      iex> equal_to("field", "value")
  """
  @spec equal_to(atom() | String.t(), any) :: Condition.t()
  def equal_to(field_name, value) do
    %Condition{
      token: :eq,
      field: field_name,
      params: [value]
    }
  end

  @doc """
  Not Equal to condition

  Returns a `Ravix.RQL.Tokens.Condition`

  ## Examples
      iex> import Ravix.RQL.Tokens.Condition
      iex> not_equal_to("field", "value")
  """
  @spec not_equal_to(atom() | String.t(), any) :: Condition.t()
  def not_equal_to(field_name, value) do
    %Condition{
      token: :ne,
      field: field_name,
      params: [value]
    }
  end

  @doc """
  Specifies that the value is in a list

  Returns a `Ravix.RQL.Tokens.Condition`

  ## Examples
      iex> import Ravix.RQL.Tokens.Condition
      iex> in?("field", [1,2,3])
  """
  @spec in?(atom() | String.t(), list()) :: Condition.t()
  def in?(field_name, values) do
    %Condition{
      token: :in,
      field: field_name,
      params: values
    }
  end

  @doc """
  Specifies that the value is not in a list

  Returns a `Ravix.RQL.Tokens.Condition`

  ## Examples
      iex> import Ravix.RQL.Tokens.Condition
      iex> not_in("field", ["a", "b", "c"])
  """
  @spec not_in(atom() | String.t(), list()) :: Condition.t()
  def not_in(field_name, values) do
    %Condition{
      token: :nin,
      field: field_name,
      params: values
    }
  end

  @doc """
  Specifies that the value is between two values

  Returns a `Ravix.RQL.Tokens.Condition`

  ## Examples
      iex> import Ravix.RQL.Tokens.Condition
      iex> between("field", [15,25])
  """
  @spec between(atom() | String.t(), list()) :: Condition.t()
  def between(field_name, values) do
    %Condition{
      token: :between,
      field: field_name,
      params: values
    }
  end
end

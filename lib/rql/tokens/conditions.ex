defmodule Ravix.RQL.Tokens.Condition do
  defstruct [
    :token,
    :field,
    :params
  ]

  alias Ravix.RQL.Tokens.Condition

  @type t :: %Condition{
          token: atom(),
          field: String.t(),
          params: list()
        }

  @spec greater_than(String.t(), any) :: Condition.t()
  def greater_than(field_name, value) do
    %Condition{
      token: :greater_than,
      field: field_name,
      params: [value]
    }
  end

  @spec greater_than_or_equal_to(String.t(), any) :: Condition.t()
  def greater_than_or_equal_to(field_name, value) do
    %Condition{
      token: :greater_than_or_eq,
      field: field_name,
      params: [value]
    }
  end

  @spec lower_than(String.t(), any) :: Condition.t()
  def lower_than(field_name, value) do
    %Condition{
      token: :lower_than,
      field: field_name,
      params: [value]
    }
  end

  @spec lower_than_or_equal_to(String.t(), any) :: Condition.t()
  def lower_than_or_equal_to(field_name, value) do
    %Condition{
      token: :lower_than_or_eq,
      field: field_name,
      params: [value]
    }
  end

  @spec equal_to(String.t(), any) :: Condition.t()
  def equal_to(field_name, value) do
    %Condition{
      token: :eq,
      field: field_name,
      params: [value]
    }
  end

  @spec in?(String.t(), any) :: Condition.t()
  def in?(field_name, values) do
    %Condition{
      token: :in,
      field: field_name,
      params: values
    }
  end

  @spec between(String.t(), any) :: Condition.t()
  def between(field_name, values) do
    %Condition{
      token: :between,
      field: field_name,
      params: values
    }
  end
end

defmodule Ravix.RQL.Tokens.Condition do
  defstruct [
    :token,
    :field,
    :param
  ]

  alias Ravix.RQL.Tokens.Condition

  def greater_than(field_name, value) do
    %Condition{
      token: :greater_than,
      field: field_name,
      param: value
    }
  end

  def greater_than_or_equal_to(field_name, value) do
    %Condition{
      token: :greater_than_or_eq,
      field: field_name,
      param: value
    }
  end

  def lower_than(field_name, value) do
    %Condition{
      token: :lower_than,
      field: field_name,
      param: value
    }
  end

  def lower_than_or_equal_to(field_name, value) do
    %Condition{
      token: :lower_than_or_eq,
      field: field_name,
      param: value
    }
  end

  def equal_to(field_name, value) do
    %Condition{
      token: :eq,
      field: field_name,
      param: value
    }
  end
end

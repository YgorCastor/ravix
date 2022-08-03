defmodule Ravix.RQL.Tokens.Order do
  @moduledoc false
  defstruct [
    :token,
    :fields
  ]

  alias Ravix.RQL.Tokens.Order

  @type order_direction :: :asc | :desc
  @type order_field_type :: :lexicographicaly | :numeric

  @type t :: %Order{
          token: atom(),
          fields: list(Order.Field.t())
        }

  @spec by(list(Order.Field.t()) | Order.Field.t()) :: Order.t()
  def by(ordering) when is_list(ordering) do
    %Order{
      token: :order_by,
      fields: ordering
    }
  end

  def by(%Order.Field{} = order) do
    %Order{
      token: :order_by,
      fields: [order]
    }
  end
end

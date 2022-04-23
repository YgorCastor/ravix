defmodule Ravix.RQL.Tokens.Order do
  @moduledoc false
  defstruct [
    :token,
    :fields
  ]

  alias Ravix.RQL.Tokens.Order

  @type t :: %Order{
          token: atom(),
          fields: list({:asc | :desc, String.t()})
        }

  @spec by([{:asc | :desc, String.t()}, ...] | {:asc | :desc, String.t()}) :: Order.t()
  def by(ordering) when is_list(ordering) do
    %Order{
      token: :order_by,
      fields: ordering
    }
  end

  def by({_order, _field} = order) do
    %Order{
      token: :order_by,
      fields: [order]
    }
  end
end

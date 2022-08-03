defmodule Ravix.RQL.Tokens.Order.Field do
  defstruct order: :desc,
            name: nil,
            type: :lexicographicaly

  @type t :: %__MODULE__{
          order: Ravix.RQL.Tokens.Order.order_direction(),
          name: binary(),
          type: Ravix.RQL.Tokens.Order.order_field_type()
        }
end

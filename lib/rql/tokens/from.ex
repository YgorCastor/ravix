defmodule Ravix.RQL.Tokens.From do
  defstruct [
    :token,
    :as_alias,
    :document_or_index
  ]

  alias Ravix.RQL.Tokens.From

  def from(nil, as_alias), do: {:error, :collection_not_informed}

  def from(document, as_alias) do
    %From{
      token: :from,
      as_alias: as_alias,
      document_or_index: document
    }
  end

  def from_index(nil), do: {:error, :index_not_informed}

  def from_index(index) do
    %From{
      token: :from_index,
      document_or_index: index
    }
  end
end

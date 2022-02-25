defmodule Ravix.RQL.Tokens.From do
  defstruct [
    :token,
    :as_alias,
    :document_or_index
  ]

  alias Ravix.RQL.Tokens.From

  @type t :: %From{
          token: atom(),
          as_alias: boolean(),
          document_or_index: String.t()
        }

  @spec from(any, any) :: {:error, :collection_not_informed} | From.t()
  def from(nil, _as_alias), do: {:error, :collection_not_informed}

  def from(document, as_alias) do
    %From{
      token: :from,
      as_alias: as_alias,
      document_or_index: document
    }
  end

  @spec from_index(any) :: {:error, :index_not_informed} | From.t()
  def from_index(nil), do: {:error, :index_not_informed}

  def from_index(index) do
    %From{
      token: :from_index,
      document_or_index: index
    }
  end
end

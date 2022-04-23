defmodule Ravix.RQL.Tokens.From do
  @moduledoc false
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

  @spec from(any) :: {:error, :collection_not_informed} | From.t()
  def from(nil), do: {:error, :collection_not_informed}

  def from(document) do
    %From{
      token: :from,
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

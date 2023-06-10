defmodule Ravix.Connection.Executor.RavenResponse do
  defstruct body: nil, status_code: nil, headers: nil

  alias __MODULE__

  @type t :: %RavenResponse{
          body: any(),
          status_code: integer(),
          headers: keyword()
        }

  def response_etag(%RavenResponse{} = response) do
    case response.headers |> Enum.find(fn {key, _} -> key == "etag" end) do
      nil -> {:no_etag, response}
      {_, etag} -> {:ok, etag}
    end
  end
end

defmodule Ravix.Connection.Executor.RavenResponse do
  defstruct body: nil, status_code: nil, headers: nil

  alias __MODULE__

  @type t :: %RavenResponse{
          body: any(),
          status_code: integer(),
          headers: keyword()
        }

  def response_etag(%RavenResponse{} = response), do: response.headers["ETag"]
end

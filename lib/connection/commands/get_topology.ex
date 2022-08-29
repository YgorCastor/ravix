defmodule Ravix.Connection.Commands.GetTopology do
  @moduledoc """
  Command to fetch the topology data from RavenDB

  ## Fields
  - database_name: The name of the database
  - force_url: Forces the informed url to the new topology
  """
  use Ravix.Documents.Commands.RavenCommand,
    database_name: nil,
    force_url: nil

  import Ravix.Helpers.UrlBuilder
  import Ravix.Documents.Commands.RavenCommand

  alias Ravix.Connection.Commands.GetTopology
  alias Ravix.Connection.ServerNode
  alias Ravix.Documents.Protocols.CreateRequest

  command_type(%{
    database_name: String.t(),
    force_url: String.t() | nil
  })

  defimpl CreateRequest, for: GetTopology do
    @spec create_request(GetTopology.t(), ServerNode.t()) :: GetTopology.t()
    def create_request(%GetTopology{} = command, _) do
      %GetTopology{
        command
        | url:
            "/topology?"
            |> append_param("name", command.database_name)
            |> append_param("url", command.force_url),
          method: :get,
          is_read_request: true
      }
    end
  end
end

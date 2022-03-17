defmodule Ravix.Connection.Commands.GetStatistics do
  use Ravix.Documents.Commands.RavenCommand,
    debug_tag: nil

  import Ravix.Documents.Commands.RavenCommand

  alias Ravix.Connection.Commands.GetStatistics
  alias Ravix.Connection.ServerNode
  alias Ravix.Documents.Protocols.CreateRequest

  command_type(%{
    debug_tag: String.t()
  })

  defimpl CreateRequest, for: GetStatistics do
    @spec create_request(GetStatistics.t(), ServerNode.t()) :: GetStatistics.t()
    def create_request(%GetStatistics{} = command, %ServerNode{} = node) do
      base_url = ServerNode.node_url(node)

      %GetStatistics{
        command
        | url:
            "#{base_url}/stats?" <>
              case command.debug_tag do
                nil -> ""
                tag -> tag
              end,
          method: "GET",
          is_read_request: true
      }
    end
  end
end

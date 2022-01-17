defmodule Ravix.Documents.Commands.GetDocuments do
  use Ravix.Documents.Commands.RavenCommand,
    ids: [],
    includes: nil,
    metadata_only: false,
    start: nil,
    page_size: nil,
    counter_includes: []

  import Ravix.Helpers.UrlBuilder
  import Ravix.Documents.Commands.RavenCommand

  alias Ravix.Documents.Protocols.CreateRequest
  alias Ravix.Documents.Commands.GetDocuments
  alias Ravix.Connection.ServerNode

  command_type(%{
    ids: list(String.t()),
    includes: list(String.t()) | nil,
    metadata_only: boolean() | nil,
    start: non_neg_integer() | nil,
    page_size: non_neg_integer() | nil,
    counter_includes: list(String.t()) | nil
  })

  defimpl CreateRequest, for: GetDocuments do
    @spec create_request(GetDocuments.t(), ServerNode.t()) :: map()
    def create_request(command = %GetDocuments{}, server_node = %ServerNode{}) do
      base_url = server_node |> ServerNode.node_url()

      %GetDocuments{
        command
        | method: "GET",
          is_read_request: true,
          url:
            "#{base_url}/docs?"
            |> append_param("id", command.ids)
            |> append_param("start", command.start)
            |> append_param("pageSize", command.page_size)
            |> append_param("metadataOnly", command.metadata_only)
            |> append_param("includes", command.includes)
      }
    end
  end
end

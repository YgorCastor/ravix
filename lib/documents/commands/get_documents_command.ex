defmodule Ravix.Documents.Commands.GetDocumentsCommand do
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
  alias Ravix.Documents.Commands.GetDocumentsCommand
  alias Ravix.Documents.Session.{SessionDocument, State}
  alias Ravix.Connection.ServerNode

  command_type(%{
    ids: list(String.t()),
    includes: list(String.t()) | nil,
    metadata_only: boolean() | nil,
    start: non_neg_integer() | nil,
    page_size: non_neg_integer() | nil,
    counter_includes: list(String.t()) | nil
  })

  @spec parse_response(State.t(), map) :: [{:includes, list()} | {:results, list}, ...]
  def parse_response(session_state, documents_response) do
    [
      results: extract_results(session_state, Map.get(documents_response, "Results")),
      includes: extract_includes(session_state, Map.get(documents_response, "Includes"))
    ]
  end

  defp extract_results(session_state, results) do
    results
    |> Enum.reject(fn batch_item -> batch_item == nil end)
    |> Enum.map(fn batch_item ->
      {:ok, :update_document, SessionDocument.upsert_document(session_state, batch_item)}
    end)
  end

  defp extract_includes(session_state, includes) do
    includes
    |> Enum.map(fn {doc_id, document} ->
      {:ok, :update_document, SessionDocument.upsert_document(session_state, doc_id, document)}
    end)
  end

  defimpl CreateRequest, for: GetDocumentsCommand do
    @spec create_request(GetDocumentsCommand.t(), ServerNode.t()) :: map()
    def create_request(command = %GetDocumentsCommand{}, server_node = %ServerNode{}) do
      base_url = server_node |> ServerNode.node_url()

      %GetDocumentsCommand{
        command
        | method: "GET",
          is_read_request: true,
          url:
            "#{base_url}/docs?"
            |> append_param("id", command.ids)
            |> append_param("start", command.start)
            |> append_param("pageSize", command.page_size)
            |> append_param("metadataOnly", command.metadata_only)
            |> append_param("include", command.includes)
      }
    end
  end
end

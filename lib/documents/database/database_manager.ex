defmodule Ravix.Documents.DatabaseManager do
  require OK

  alias Ravix.Connection.{RequestExecutor, ServerNode}
  alias Ravix.Documents.Commands.CreateDatabaseCommand

  @spec create_database(
          binary,
          binary | URI.t(),
          %{:certificate => any, :certificate_file => any, optional(any) => any},
          keyword
        ) :: {:error, any} | {:ok, map()}
  def create_database(database_name, url, certificate, opts \\ []) do
    OK.for do
      response <-
        %CreateDatabaseCommand{
          DatabaseName: database_name,
          Encrypted: Keyword.get(opts, :encrypted, false),
          Disabled: Keyword.get(opts, :disabled, false),
          ReplicationFactor: Keyword.get(opts, :replication_factor, 1)
        }
        |> RequestExecutor.execute_for_node(certificate, ServerNode.from_url(url, database_name))
    after
      response.data
    end
  end
end

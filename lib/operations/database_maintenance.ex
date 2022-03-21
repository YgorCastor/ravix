defmodule Ravix.Operations.Database.Maintenance do
  require OK

  alias Ravix.Operations.Database.Commands.CreateDatabaseCommand
  alias Ravix.Connection.RequestExecutor

  @spec create_database(bitstring | pid, String.t(), keyword) :: {:error, any} | {:ok, any}
  def create_database(node_pid, database_name, opts \\ []) do
    OK.for do
      response <-
        %CreateDatabaseCommand{
          DatabaseName: database_name,
          Encrypted: Keyword.get(opts, :encrypted, false),
          Disabled: Keyword.get(opts, :disabled, false),
          ReplicationFactor: Keyword.get(opts, :replication_factor, 1)
        }
        |> RequestExecutor.execute_for_node(
          node_pid,
          {},
          opts
        )
    after
      response.data
    end
  end
end

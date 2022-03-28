defmodule Ravix.Operations.Database.Maintenance do
  @moduledoc """
  Database maintenance operations module
  """
  require OK

  alias Ravix.Operations.Database.Commands.CreateDatabaseCommand
  alias Ravix.Connection.RequestExecutor

  @doc """
  Creates a database using the informed request executor
  """
  @spec create_database(atom | pid, nil | binary, keyword) :: {:error, any} | {:ok, any}
  def create_database(store_or_pid, database_name, opts \\ [])

  def create_database(store, database_name, opts) when is_atom(store) do
    node_pid = RequestExecutor.Supervisor.fetch_nodes(store) |> Enum.at(0)

    create_database(node_pid, database_name, opts)
  end

  def create_database(node_pid, database_name, opts) when is_pid(node_pid) do
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
          database_name,
          {},
          opts
        )
    after
      response.data
    end
  end
end

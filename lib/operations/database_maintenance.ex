defmodule Ravix.Operations.Database.Maintenance do
  @moduledoc """
  Database maintenance operations module
  """
  require OK

  alias Ravix.Operations.Database.Commands.{
    CreateDatabaseCommand,
    DeleteDatabaseCommand,
    GetStatisticsCommand
  }

  alias Ravix.Connection.RequestExecutor

  @doc """
  Creates a database using the informed request executor

  Options:
  - :encrypted = true/false
  - :disabled = true/false
  - :replication_factor = 1-N

  ## Examples
      iex> Ravix.Operations.Database.Maintenance.create_database(Ravix.Test.Store, "test_db")
      {:ok,
      %{
        "Name" => "test_db",
        "NodesAddedTo" => ["http://4e0373cbf5d0:8080"],
        "RaftCommandIndex" => 443,
        "Topology" => %{
          "ClusterTransactionIdBase64" => "mdO7gPZsMEeslGOxxNfpjA",
          "DatabaseTopologyIdBase64" => "0FHV8Uc0jEi94uZQiT00mA",
          "DemotionReasons" => %{},
          "DynamicNodesDistribution" => false,
          "Members" => ["A"],
          "NodesModifiedAt" => "2022-04-23T11:00:06.9470373Z",
          "PriorityOrder" => [],
          "Promotables" => [],
          "PromotablesStatus" => %{},
          "Rehabs" => [],
          "ReplicationFactor" => 1,
          "Stamp" => %{"Index" => 443, "LeadersTicks" => -2, "Term" => 4}
        }
      }}
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

  @spec delete_database(atom | pid, nil | binary, keyword) :: {:error, any} | {:ok, any}
  def delete_database(store_or_pid, database_name, opts \\ [])

  def delete_database(store, database_name, opts) when is_atom(store) do
    node_pid = RequestExecutor.Supervisor.fetch_nodes(store) |> Enum.at(0)

    delete_database(node_pid, database_name, opts)
  end

  def delete_database(node_pid, database_name, opts) when is_pid(node_pid) do
    OK.for do
      response <-
        %DeleteDatabaseCommand{
          DatabaseNames: [database_name],
          HardDelete: Keyword.get(opts, :hard_delete, false),
          TimeToWaitForConfirmation: Keyword.get(opts, :time_for_confirmation, 100)
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

  @spec database_stats(atom | pid, nil | binary, keyword) :: {:error, any} | {:ok, any}
  def database_stats(store_or_pid, database_name, opts \\ [])

  def database_stats(store, database_name, opts) when is_atom(store) do
    node_pid = RequestExecutor.Supervisor.fetch_nodes(store) |> Enum.at(0)

    database_stats(node_pid, database_name, opts)
  end

  def database_stats(node_pid, database_name, opts) when is_pid(node_pid) do
    OK.for do
      response <-
        %GetStatisticsCommand{
          debugTag: Keyword.get(opts, :debug_tag, "")
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

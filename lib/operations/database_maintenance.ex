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

  alias Ravix.Connection.{RequestExecutor, State}

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
  @spec create_database(State.t(), keyword) :: {:error, any} | {:ok, any}
  def create_database(conn_state, opts \\ []) do
    OK.for do
      response <-
        %CreateDatabaseCommand{
          DatabaseName: conn_state.database,
          Encrypted: Keyword.get(opts, :encrypted, false),
          Disabled: Keyword.get(opts, :disabled, false),
          ReplicationFactor: Keyword.get(opts, :replication_factor, 1)
        }
        |> RequestExecutor.execute(conn_state)
    after
      response
    end
  end

  @spec delete_database(State.t(), keyword) :: {:error, any} | {:ok, any}
  def delete_database(conn_state, opts \\ []) do
    OK.for do
      response <-
        %DeleteDatabaseCommand{
          DatabaseNames: [conn_state.database],
          HardDelete: Keyword.get(opts, :hard_delete, false),
          TimeToWaitForConfirmation: Keyword.get(opts, :time_for_confirmation, 100)
        }
        |> RequestExecutor.execute(conn_state)
    after
      response
    end
  end

  @spec database_stats(State.t(), keyword) :: {:error, any} | {:ok, any}
  def database_stats(conn_state, opts \\ []) do
    OK.for do
      response <-
        %GetStatisticsCommand{
          debugTag: Keyword.get(opts, :debug_tag, ""),
          databaseName: conn_state.database
        }
        |> RequestExecutor.execute(conn_state)
    after
      response
    end
  end
end

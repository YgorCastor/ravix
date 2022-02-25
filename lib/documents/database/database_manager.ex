defmodule Ravix.Documents.DatabaseManager do
  require OK

  alias Ravix.Connection.RequestExecutor
  alias Ravix.Connection.NetworkStateManager
  alias Ravix.Documents.Commands.CreateDatabaseCommand

  @spec create_database(binary, list()) :: {:error, any} | {:ok, any}
  def create_database(database_name, opts \\ []) do
    OK.for do
      {pid, _} <- NetworkStateManager.find_existing_network(database_name)
      network_state = Agent.get(pid, fn ns -> ns end)
      response <- execute_create_db_request(network_state, database_name, opts)
    after
      response
    end
  end

  defp execute_create_db_request(network_state, database_name, opts) do
    OK.try do
      response <-
        %CreateDatabaseCommand{
          DatabaseName: database_name,
          Encrypted: Keyword.get(opts, :encrypted, false),
          Disabled: Keyword.get(opts, :disabled, false),
          ReplicationFactor: Keyword.get(opts, :replication_factor, 1)
        }
        |> RequestExecutor.execute(network_state)

      parsed_response <- Jason.decode(response.data)
    after
      case parsed_response do
        error_response when is_map_key(error_response, "Error") ->
          {:error, error_response["Message"]}

        _ ->
          {:ok, parsed_response}
      end
    rescue
      err -> {:error, err}
    end
  end
end

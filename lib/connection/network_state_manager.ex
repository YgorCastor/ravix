defmodule Ravix.Connection.NetworkStateManager do
  use DynamicSupervisor

  alias Ravix.Connection.InMemoryNetworkState

  def init(init_arg) do
    DynamicSupervisor.init(
      strategy: :one_for_one,
      extra_arguments: [init_arg]
    )
  end

  def start_link(attrs) do
    DynamicSupervisor.start_link(__MODULE__, attrs, name: __MODULE__)
  end

  @spec create_network_state(any, binary, any, any) ::
          :ignore | {:error, any} | {:ok, pid} | {:ok, pid, any}
  def create_network_state(urls, database_name, conventions, certificate \\ nil) do
    with network when network == {:error, :network_not_found} <-
           find_existing_network(database_name) do
      DynamicSupervisor.start_child(
        __MODULE__,
        {InMemoryNetworkState,
         [
           urls: urls,
           database_name: database_name,
           document_conventions: conventions,
           certificate: certificate
         ]}
      )
    else
      existing_network -> existing_network
    end
  end

  @spec network_exists?(binary) :: boolean
  def network_exists?(database), do: find_existing_network(database) |> Enum.count() > 1

  @spec find_existing_network(String.t()) :: {:ok, {pid, any}} | {:error, :network_not_found}
  def find_existing_network(database) do
    case Registry.lookup(:network_state, database) do
      existing_network when existing_network != [] -> {:ok, Enum.at(existing_network, 0)}
      _ -> {:error, :network_not_found}
    end
  end

  @spec network_state_for_database(String.t()) :: {:via, Registry, {:network_state, String.t()}}
  def network_state_for_database(database),
    do: {:via, Registry, {:network_state, database}}
end

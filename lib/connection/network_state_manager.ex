defmodule Ravix.Connection.NetworkStateManager do
  use DynamicSupervisor

  alias Ravix.Connection.InMemoryNetworkState
  alias Ravix.Connection.NetworkStateManager
  alias Ravix.Documents.Conventions

  def init(init_arg) do
    DynamicSupervisor.init(
      strategy: :one_for_one,
      extra_arguments: [init_arg]
    )
  end

  def start_link(attrs) do
    DynamicSupervisor.start_link(__MODULE__, attrs, name: __MODULE__)
  end

  @spec create_network_state(list(String.t()), String.t(), Conventions.t(), any) :: {:ok, pid}
  def create_network_state(urls, database_name, conventions, certificate \\ nil) do
    with networks when networks == [] <- NetworkStateManager.find_existing_network(database_name) do
      DynamicSupervisor.start_child(
        __MODULE__,
        {InMemoryNetworkState,
         [
           urls: urls,
           database_name: database_name,
           document_conventions: conventions,
           certificate: certificate,
         ]}
      )
    else
      existing_networks -> existing_networks[0]
    end
  end

  @spec find_existing_network(String.t()) :: [{pid, any}]
  def find_existing_network(database) do
    Registry.lookup(:network_state, database)
  end
end

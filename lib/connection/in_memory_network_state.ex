defmodule Ravix.Connection.InMemoryNetworkState do
  use Agent

  alias Ravix.Connection.Network.State

  def start_link(_attrs, params) do
    Agent.start_link(
      fn ->
        State.initial_state(
          params[:urls],
          params[:database_name],
          params[:document_conventions],
          params[:certificate]
        )
      end,
      name: network_state_for_database(params[:database_name])
    )
  end

  defp network_state_for_database(database), do: {:via, Registry, {:network_state, database}}
end

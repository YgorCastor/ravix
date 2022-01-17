defmodule Ravix.Connection.InMemoryNetworkState do
  use Agent

  alias Ravix.Connection.Network.State
  alias Ravix.Connection.NetworkStateManager

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
      name: NetworkStateManager.network_state_for_database(params[:database_name])
    )
  end
end

defmodule Ravix do
  use Supervisor

  alias Ravix.Documents.Session.SessionsSupervisor
  alias Ravix.Connection.NetworkStateManager
  alias Ravix.Documents.Store

  def init(opts) do
    children = [
      ## Supervisor for the session and the Unique Application Store Server
      %{id: SessionsSupervisor, start: {SessionsSupervisor, :start_link, [%{}]}},
      %{id: NetworkStateManager, start: {NetworkStateManager, :start_link, [%{}]}},
      %{id: Store, start: {Store, :start_link, opts}},
      ## Registry so we can easily fetch the sessions by it's id
      {Registry, [keys: :unique, name: :sessions]},
      ## Registry to fetch already created requests executor
      {Registry, [keys: :unique, name: :network_state]}
    ]

    Supervisor.init(
      children,
      strategy: :one_for_one
    )
  end

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end
end

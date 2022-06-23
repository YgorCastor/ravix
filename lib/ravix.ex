defmodule Ravix do
  @moduledoc """
    Ravix is a RavenDB Driver written in Elixir
  """
  use Application

  @doc """
    Initializes three processes registers to facilitate grouping sessions, connections and nodes.
    - :sessions = Stores sessions by their UUIDs
    - :connections = Stores the connections processes, based on the Repo Name
    - :request_executors = Stores the node executors data
  """
  def start(_type, _args) do
    children = [
      {Registry, [keys: :unique, name: :sessions]},
      {Registry, [keys: :unique, name: :connections]},
      {Registry, [keys: :duplicate, name: :request_executors]},
      {Registry, [keys: :unique, name: :request_executor_pools]}
    ]

    opts = [strategy: :one_for_one, name: Ravix.Supervisor]
    Supervisor.start_link(children, opts)
  end
end

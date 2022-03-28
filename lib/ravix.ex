defmodule Ravix do
  @moduledoc """
    Ravix is a RavenDB Driver written in Elixir
  """
  use Supervisor

  @doc """
    Initializes three processes registers to facilitate grouping sessions, connections and nodes.
    - :sessions = Stores sessions by their UUIDs 
    - :connections = Stores the connections processes, based on the Repo Name
    - :request_executors = Stores the node executors data
  """
  def init(_opts) do
    children = [
      {Registry, [keys: :unique, name: :sessions]},
      {Registry, [keys: :unique, name: :connections]},
      {Registry, [keys: :unique, name: :request_executors]}
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

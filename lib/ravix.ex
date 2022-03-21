defmodule Ravix do
  use Supervisor

  def init(_opts) do
    children = [
      ## Registry so we can easily fetch the sessions by it's id
      {Registry, [keys: :unique, name: :sessions]},
      ## Registry for Connections
      {Registry, [keys: :unique, name: :connections]},
      ## Registry for Node Executors
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

defmodule Ravix.TestApplication do
  use Supervisor

  def init(_opts) do
    children = [
      {Ravix, [%{}]},
      {Ravix.TestStore, [%{}]},
      {Ravix.TestStore2, [%{}]}
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

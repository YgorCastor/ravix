defmodule Ravix.TestApplication do
  @moduledoc false
  use Supervisor

  def init(_opts) do
    children = [
      {Ravix.Test.Store, [%{}]},
      {Ravix.Test.NonRetryableStore, [%{}]},
      {Ravix.Test.OptimisticLockStore, [%{}]}
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

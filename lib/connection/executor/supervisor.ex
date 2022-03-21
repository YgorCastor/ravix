defmodule Ravix.Connection.RequestExecutor.Supervisor do
  use DynamicSupervisor

  alias Ravix.Connection.{RequestExecutor, ServerNode, Topology}

  def init(init_arg) do
    DynamicSupervisor.init(
      strategy: :one_for_one,
      extra_arguments: [init_arg]
    )
  end

  def start_link(store) do
    DynamicSupervisor.start_link(__MODULE__, %{}, name: supervisor_name(store))
  end

  def register_node_executor(store, %ServerNode{} = node) do
    DynamicSupervisor.start_child(supervisor_name(store), {RequestExecutor, node})
  end

  def fetch_nodes(store) do
    DynamicSupervisor.which_children(supervisor_name(store))
    |> Enum.map(fn {_executor, pid, _kind, _children} -> pid end)
  end

  def update_nodes(store, %Topology{} = _topology) do
    pids = fetch_nodes(store)

    {:ok, pids}
  end

  defp supervisor_name(store) do
    :"#{store}.Executor"
  end
end

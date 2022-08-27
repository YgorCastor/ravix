defmodule Ravix.Connection.RequestExecutor.Supervisor do
  @moduledoc false
  use DynamicSupervisor

  require Logger

  alias Ravix.Connection.{RequestExecutor, ServerNode, Topology, NodeSelector}

  def init(init_arg) do
    DynamicSupervisor.init(
      strategy: :one_for_one,
      extra_arguments: [init_arg]
    )
  end

  @spec start_link(any) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(store) do
    DynamicSupervisor.start_link(__MODULE__, %{}, name: supervisor_name(store))
  end

  def fetch_nodes(store) do
    DynamicSupervisor.which_children(supervisor_name(store))
    |> Enum.map(fn {_, pid, _, _} -> pid end)
    |> Enum.filter(&(&1 != :restarting))
  end

  def register_node(node = %ServerNode{}) do
    Logger.debug(
      "[RAVIX] Registering the connection with the node '#{node.url}' for the store '#{node.store}'"
    )

    DynamicSupervisor.start_child(supervisor_name(node.store), {RequestExecutor, node})
  end

  def update_topology(store, %Topology{} = topology) do
    Logger.info("[RAVIX] A topology update was requested by the server, updating nodes...")
  end

  defp supervisor_name(store) do
    :"#{store}.Executor"
  end
end

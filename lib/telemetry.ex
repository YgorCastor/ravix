defmodule Ravix.Telemetry do
  @moduledoc """
     Telemetry events supported by the Ravix Driver

     All the events follow the [:ravix, store_atom] prefix

     In addition to the specific Ravix events, all the Tesla events
     are also propagated
  """

  @doc """
     Fires when a node is selected, can be filtered by the node url
  """
  def node_selected({pid, node}) do
    :telemetry.execute(
      [:ravix, node.store, :node_selected, :count],
      %{count: 1},
      %{node_url: node.url}
    )

    {pid, node}
  end

  @doc """
    Fires when a topology request is requested
  """
  def topology_updated(store) do
    :telemetry.execute(
      [:ravix, store, :topology_updates, :count],
      %{count: 1}
    )
  end

  @doc """
    Fires when a retry is requested, can be filtered by the node url or http status
  """
  def retry_count(node, status) do
    :telemetry.execute(
      [:ravix, node.store, :retries, :count],
      %{count: 1},
      %{node_url: node.url, status: status}
    )
  end

  @doc """
     Fires when a request ends in error, can be filtered by node url or status
  """
  def request_error(node, status) do
    :telemetry.execute(
      [:ravix, node.store, :requests, :error],
      %{count: 1},
      %{node_url: node.url, status: status}
    )
  end

  @doc """
     Fires when there's a request to a stale index, can be filtered by the node url or index name
  """
  def request_stale(node, index_name) do
    :telemetry.execute(
      [:ravix, node.store, :requests, :stale_index],
      %{count: 1},
      %{node_url: node.url, index: index_name}
    )
  end

  @doc """
      Fires when a request ends successfully
  """
  def request_success(node) do
    :telemetry.execute(
      [:ravix, node.store, :requests, :success],
      %{count: 1},
      %{node_url: node.url}
    )
  end
end

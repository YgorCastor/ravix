defmodule Ravix.Connection.RequestExecutor.State do
  defstruct database_name: nil,
            certificate: nil,
            topology_etag: nil,
            last_return_response: nil,
            conventions: nil,
            node_selector: nil,
            last_known_urls: nil,
            headers: nil,
            disable_topology_updates: nil,
            cluster_token: nil,
            topology_nodes: nil
end

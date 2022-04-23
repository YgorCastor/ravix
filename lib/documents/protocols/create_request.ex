defprotocol Ravix.Documents.Protocols.CreateRequest do
  @moduledoc false

  @doc """
  Creates a request based on the command

  ## Parameters
  - command: the command who will be requested
  - selected_node: in which node will it be executed
  """
  @spec create_request(t, any) :: any
  def create_request(command, selected_node)
end

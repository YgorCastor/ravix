defprotocol Ravix.Documents.Protocols.CreateRequest do
  @spec create_request(t, any) :: any
  def create_request(command, selected_node)
end

defprotocol Ravix.Documents.Protocols.CreateRequest do
  @spec create_request(t) :: String.t()
  def create_request(command)
end

defprotocol Ravix.Documents.Protocols.ToJson do
  @moduledoc false

  @spec to_json(t) :: any()
  @fallback_to_any true
  def to_json(command)
end

defimpl Ravix.Documents.Protocols.ToJson, for: Any do
  def to_json(command) do
    Jason.encode!(command)
  end
end

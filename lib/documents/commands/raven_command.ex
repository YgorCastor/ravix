defmodule Ravix.Documents.Commands.RavenCommand do
  @moduledoc """
  Macro to define the basic required fields for a RavenCommand

  ## Fields
  - url: Where the command will be executed
  - method: HTTP Method
  - data: The json body payload
  - headers: HTTP headers to send to Raven
  - is_read_request: If this request is read_only
  - use_stream: If the request will use HTTP/2 stream
  - timeout: Timeout for this command in ms
  - files: Files to attach
  - is_raft_request: If the request will be executed using Rachi Consensus
  - raft_unique_request_id: The rachi consensus id for this request
  """
  @base_fields [
    url: nil,
    method: nil,
    data: nil,
    headers: [],
    is_read_request: false,
    use_stream: false,
    timeout: nil,
    files: [],
    is_raft_request: false,
    raft_unique_request_id: nil
  ]
  defmacro __using__(fields) do
    fields = @base_fields ++ fields

    quote do
      defstruct unquote(fields)
    end
  end

  defmacro command_type(fields) do
    fields_map =
      case fields do
        {:%{}, _, flist} -> Enum.into(flist, %{})
        _ -> raise ArgumentError, "Fields must be a map!"
      end

    field_specs = Map.to_list(fields_map)

    quote do
      @type t :: %__MODULE__{
              unquote_splicing(field_specs)
            }
    end
  end
end

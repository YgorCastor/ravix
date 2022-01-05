defmodule Ravix.Documents.Commands.RavenCommand do
  @base_fields [
    url: nil,
    method: nil,
    data: nil,
    headers: [],
    is_read_request: false,
    use_stream: false,
    failed_nodes: nil,
    timeout: nil,
    requested_node: nil,
    files: nil,
    is_raft_request: nil,
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

defmodule Ravix.Document do
  @base_fields [:"@metadata"]

  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      {fields, only, except} = compile_configs(opts)

      fields = @base_fields ++ fields

      defstruct unquote(fields)

      defp compile_configs(opts) do
        fields = Keyword.get(opts, :fields)
        only = Keyword.get(opts, :only)
        except = Keyword.get(opts, :except)

        {fields, only, except}
      end
    end
  end
end

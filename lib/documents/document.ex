defmodule Ravix.Document do
  @moduledoc """
  Macro to facilitate the representation of a Raven Document

  ## Example

      `defmodule Ravix.TestDocument do
         use Ravix.Document, fields: [
           name: nil,
           id: nil
         ]
       end`
  """
  defmacro compile_configs(opts) do
    quote bind_quoted: [opts: opts] do
      fields = Keyword.get(opts, :fields)
      only = Keyword.get(opts, :only)
      except = Keyword.get(opts, :except)

      {fields, only, except}
    end
  end

  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      import Ravix.Document
      @base_fields [:"@metadata"]

      {fields, only, except} = compile_configs(opts)

      fields = @base_fields ++ fields

      if only != nil do
        @derive {Jason.Encoder, only: only}
      end

      if except != nil && only == nil do
        @derive {Jason.Encoder, except: except}
      end

      if except == nil && only == nil do
        @derive Jason.Encoder
      end

      defstruct fields
    end
  end
end

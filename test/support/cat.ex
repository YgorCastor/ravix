defmodule Ravix.SampleModel.Cat do
  @derive {Jason.Encoder, only: [:id, :name, :breed, :"@metadata"]}
  defstruct [:id, :name, :breed, :"@metadata"]
end

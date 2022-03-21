defmodule Ravix.Connection.State do
  defstruct store: nil,
            database: nil,
            certificate: nil,
            certificate_file: nil,
            conventions: %Ravix.Documents.Conventions{},
            node_selector: nil,
            urls: [],
            disable_topology_updates: false,
            cluster_token: nil

  use Vex.Struct

  @type t :: %Ravix.Connection.State{
          store: any(),
          database: String.t(),
          certificate: String.t() | nil,
          certificate_file: String.t() | nil,
          conventions: Ravix.Documents.Conventions.t(),
          node_selector: NodeSelector.t(),
          urls: list(String.t()),
          disable_topology_updates: boolean(),
          cluster_token: String.t() | nil
        }

  def validate_configs(%Ravix.Connection.State{} = configs) do
    case Vex.valid?(configs) do
      true -> {:ok, configs}
      false -> {:error, Vex.errors(configs)}
    end
  end
end

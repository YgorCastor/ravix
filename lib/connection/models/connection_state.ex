defmodule Ravix.Connection.State do
  defstruct store: nil,
            database: nil,
            certificate: nil,
            certificate_file: nil,
            conventions: %Ravix.Documents.Conventions{},
            node_selector: nil,
            urls: [],
            topology_etag: nil,
            disable_topology_updates: false,
            force_create_database: false,
            cluster_token: nil

  use Vex.Struct

  @type t :: %Ravix.Connection.State{
          store: any(),
          database: String.t(),
          certificate: String.t() | nil,
          certificate_file: String.t() | nil,
          conventions: Ravix.Documents.Conventions.t(),
          node_selector: Ravix.Connection.NodeSelector.t(),
          urls: list(String.t()),
          topology_etag: String.t() | nil,
          disable_topology_updates: boolean(),
          force_create_database: boolean(),
          cluster_token: String.t() | nil
        }

  @spec validate_configs(Ravix.Connection.State.t()) ::
          {:error, list} | {:ok, Ravix.Connection.State.t()}
  def validate_configs(%Ravix.Connection.State{} = configs) do
    case Vex.valid?(configs) do
      true -> {:ok, configs}
      false -> {:error, Vex.errors(configs)}
    end
  end
end

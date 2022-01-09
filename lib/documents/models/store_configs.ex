defmodule Ravix.Documents.Store.Configs do
  defstruct urls: [],
            database: nil,
            document_conventions: %{
              max_number_of_requests_per_session: nil,
              max_ids_to_catch: nil,
              timeout: nil,
              use_optimistic_concurrency: nil,
              max_length_of_query_using_get_url: nil,
              identity_parts_separator: nil,
              disable_topology_update: nil
            }

  use Vex.Struct

  alias Ravix.Documents.Store.Configs

  @type t :: %Configs{
          urls: list(String.t()),
          database: String.t(),
          document_conventions: %{
            max_number_of_requests_per_session: non_neg_integer(),
            max_ids_to_catch: non_neg_integer(),
            timeout: non_neg_integer(),
            use_optimistic_concurrency: boolean(),
            max_length_of_query_using_get_url: non_neg_integer(),
            identity_parts_separator: String.t(),
            disable_topology_update: boolean()
          }
        }

  validates(
    :urls,
    presence: true,
    length: [min: 1]
  )

  validates(
    :database,
    presence: true
  )

  @spec read_configs(map) :: {:error, list} | {:ok, Ravix.Documents.Store.Configs.t()}
  def read_configs(configs) when configs != nil do
    configs
    |> Mappable.to_struct(DocumentStoreConfigs)
    |> validate_configs()
  end

  @spec read_configs :: {:error, list} | {:ok, Ravix.Documents.Store.Configs.t()}
  def read_configs() do
    %Configs{
      urls: Application.fetch_env!(:ravix, :urls),
      database: Application.fetch_env!(:ravix, :database)
    }
    |> validate_configs()
  end

  defp validate_configs(configs = %Configs{}) do
    case Vex.valid?(configs) do
      true -> {:ok, configs}
      false -> {:error, Vex.errors(configs)}
    end
  end
end

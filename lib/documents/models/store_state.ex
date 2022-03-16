defmodule Ravix.Documents.Store.State do
  defstruct urls: [],
            default_database: nil,
            document_conventions: nil

  use Vex.Struct

  alias Ravix.Documents.Store.State
  alias Ravix.Documents.Conventions

  @type t :: %State{
          urls: list(String.t()),
          default_database: String.t(),
          document_conventions: Conventions.t()
        }

  validates(
    :urls,
    presence: true,
    length: [min: 1]
  )

  validates(
    :default_database,
    presence: true
  )

  @spec read_from_config_file :: {:error, list} | {:ok, State.t()}
  def read_from_config_file() do
    %State{
      urls: Application.fetch_env!(:ravix, :urls),
      default_database: Application.fetch_env!(:ravix, :database),
      document_conventions: struct(%Conventions{}, Application.fetch_env!(:ravix, :document_conventions))
    }
    |> validate_configs()
  end

  defp validate_configs(%State{} = configs) do
    case Vex.valid?(configs) do
      true -> {:ok, configs}
      false -> {:error, Vex.errors(configs)}
    end
  end
end

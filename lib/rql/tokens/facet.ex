defmodule Ravix.RQL.Tokens.Facet do
  @moduledoc false
  defstruct [
    :token,
    :conditions
  ]

  alias Ravix.RQL.Tokens.Condition
  alias __MODULE__

  @type t :: %Facet{
          token: atom(),
          conditions: list(Condition) | String.t()
        }

  @spec condition(Condition.t() | String.t()) :: Facet.t()
  def condition(condition) do
    %Facet{
      token: :facet,
      conditions: [condition]
    }
  end

  @spec condition(Facet.t(), Condition.t()) :: Facet.t()
  def condition(facet, condition) do
    %Facet{
      facet
      | conditions: facet.conditions ++ [condition]
    }
  end

  @spec avg(Facet.t(), String.t()) :: Facet.t()
  def avg(facet, field) do
    %Facet{
      facet
      | conditions: facet.conditions ++ ["avg(#{field})"]
    }
  end

  @spec sum(Facet.t(), String.t()) :: Facet.t()
  def sum(facet, field) do
    %Facet{
      facet
      | conditions: facet.conditions ++ ["sum(#{field})"]
    }
  end

  @spec min(Facet.t(), String.t()) :: Facet.t()
  def min(facet, field) do
    %Facet{
      facet
      | conditions: facet.conditions ++ ["min(#{field})"]
    }
  end

  @spec max(Facet.t(), String.t()) :: Facet.t()
  def max(facet, field) do
    %Facet{
      facet
      | conditions: facet.conditions ++ ["max(#{field})"]
    }
  end
end

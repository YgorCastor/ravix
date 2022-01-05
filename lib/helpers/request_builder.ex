defmodule Ravix.Helpers.RequestBuilder do
  def append_param(request, param_name, param_value)

  def append_param(request, name, values) when is_list(values) do
    request
    |> build_list_params(name, values)
  end

  def append_param(request, _param_name, param_value) when param_value == nil do
    request
  end

  def append_param(request, param_name, param_value) do
    append_param(request, param_name, [param_value])
  end

  defp build_list_params(request, name, values) do
    request <> (Enum.map(values, &"&#{name}=#{&1}") |> Enum.join(""))
  end
end

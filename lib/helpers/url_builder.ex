defmodule Ravix.Helpers.UrlBuilder do
  def append_param(base_url, param_name, param_value)

  def append_param(base_url, name, values) when is_list(values),
    do:
      base_url
      |> build_list_params(name, values)

  def append_param(base_url, _param_name, param_value) when param_value == nil, do: base_url

  def append_param(base_url, param_name, param_value),
    do: append_param(base_url, param_name, [param_value])

  defp build_list_params(base_url, name, values) do
    base_url <> (Enum.map(values, &"&#{name}=#{&1}") |> Enum.join(""))
  end
end

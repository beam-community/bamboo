defmodule Bamboo.AdapterHelper do
  def hackney_opts(config) do
    config
    |> Map.get(:hackney_opts, [])
    |> Enum.concat([:with_body])
  end
end

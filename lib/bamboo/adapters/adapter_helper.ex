defmodule Bamboo.AdapterHelper do
  @default_req_options [decode_body: false]

  def req_options(config) do
    config
    |> Map.get(:req_opts, [])
    |> Keyword.merge(@default_req_options)
  end
end

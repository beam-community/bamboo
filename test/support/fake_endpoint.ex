defmodule Bamboo.FakeEndpoint do
  use Plug.Router

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Poison
  plug :match
  plug :dispatch

  def start_server do
    unless __MODULE__ in Process.registered do
      Agent.start_link(&Map.new/0, name: __MODULE__)
    end

    Plug.Adapters.Cowboy.http __MODULE__, [], port: 8765, ref: __MODULE__
  end

  def register(pid, %{
    name: name,
    params_path: params_path,
    request_path: request_path
  }) do
    Agent.update(__MODULE__, &Map.put(&1, name, pid))

    request_paths = List.wrap(request_path)

    for request_path <- request_paths do
      Agent.update(__MODULE__, &Map.put(&1, request_path, %{
        name: name, params_path: params_path
      }))
    end
  end

  post "/*request_path" do
    request_path = "/" <> Enum.join(request_path, "/")

    %{name: name, params_path: params_path} =
      Agent.get(__MODULE__, &(&1[request_path]))

    case get_in(conn.params, params_path) do
      "INVALID_EMAIL" -> conn |> send_resp(500, "Error!!")
      _ -> conn |> send_resp(200, "SENT")
    end |> send_to_parent(name)
  end

  defp send_to_parent(conn, which) do
    parent = Agent.get(__MODULE__, &Map.get(&1, which))
    send parent, {:fake_endpoint, conn}
    conn
  end
end

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

  def register(name, pid) do
    Agent.update(__MODULE__, &Map.put(&1, name, pid))
  end

  post "/test.tt/messages" do
    case Map.get(conn.params, "from") do
      "INVALID_EMAIL" -> send_resp(conn, 500, "Error!!")
      _ -> send_resp(conn, 200, "SENT")
    end |> send_to_parent("mailgun")
  end

  post "/api/1.0/messages/send.json" do
    case get_in(conn.params, ["message", "from_email"]) do
      "INVALID_EMAIL" -> conn |> send_resp(500, "Error!!")
      _ -> conn |> send_resp(200, "SENT")
    end |> send_to_parent("mandrill")
  end

  post "/api/1.0/messages/send-template.json" do
    case get_in(conn.params, ["message", "from_email"]) do
      "INVALID_EMAIL" -> conn |> send_resp(500, "Error!!")
      _ -> conn |> send_resp(200, "SENT")
    end |> send_to_parent("mandrill")
  end

  post "/mail.send.json" do
    case Map.get(conn.params, "from") do
      "INVALID_EMAIL" -> conn |> send_resp(500, "Error!!")
      _ -> conn |> send_resp(200, "SENT")
    end |> send_to_parent("sendgrid")
  end

  defp send_to_parent(conn, which) do
    parent = Agent.get(__MODULE__, fn(map) -> Map.get(map, which) end)
    send parent, {:fake_endpoint, conn}
    conn
  end
end

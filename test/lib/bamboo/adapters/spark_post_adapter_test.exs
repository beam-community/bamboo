defmodule Bamboo.SparkPostAdapterTest do
  use ExUnit.Case
  alias Bamboo.Email
  alias Bamboo.SparkPostAdapter

  @config %{adapter: SparkPostAdapter, api_key: "1234"}
  @config_no_adapter_no_key %{adapter: nil, api_key: nil}
  @config_with_bad_key %{adapter: SparkPostAdapter, api_key: nil}

  defmodule FakeSparkPost do
    use Plug.Router

    plug Plug.Parsers,
      parsers: [:urlencoded, :multipart, :json],
      pass: ["*/*"],
      json_decoder: Poison
    plug :match
    plug :dispatch

    def start_server(parent) do
      Agent.start_link(fn -> Map.new end, name: __MODULE__)
      Agent.update(__MODULE__, &Map.put(&1, :parent, parent))
      port = get_free_port()
      Application.put_env(:bamboo, :sparkpost_base_uri, "http://localhost:#{port}/")
      Plug.Adapters.Cowboy.http __MODULE__, [], port: port, ref: __MODULE__
    end

    defp get_free_port do
      {:ok, socket} = :ranch_tcp.listen(port: 0)
      {:ok, port} = :inet.port(socket)
      :erlang.port_close(socket)
      port
    end

    def shutdown do
      Plug.Adapters.Cowboy.shutdown __MODULE__
    end

    post "/transmission" do
      case Map.get(conn.params, "from") do
        "INVALID_EMAIL" -> send_resp(conn, 500, "Error!!")
        _ -> send_resp(conn, 200, "SENT")
      end |> send_to_parent
    end

    defp send_to_parent(conn) do
      parent = Agent.get(__MODULE__, fn(set) -> Map.get(set, :parent) end)
      send parent, {:fake_spark_post, conn}
      conn
    end
  end

  setup do
    FakeSparkPost.start_server(self())

    on_exit fn ->
      FakeSparkPost.shutdown
    end

    :ok
  end

  test "raises if the api key is nil" do
    assert_raise ArgumentError, ~r/no api_key set/, fn ->
      SparkPostAdapter.handle_config(%{domain: "test.tt"})
    end
  end

  test "raises if the domain is nil" do
    assert_raise ArgumentError, ~r/no domain set/, fn ->
      SparkPostAdapter.handle_config(%{api_key: "dummyapikey"})
    end
  end

  test "deliver/2 sends the to the right url" do
    new_email() |> SparkPostAdapter.deliver(@config)

    assert_receive {:fake_sparkpost, %{request_path: request_path}}

    assert request_path == "/test.tt/messages"
  end

  test "deliver/2 sends from, subject, text body, html body and headers" do
    email = new_email(
      from: "from@foo.com",
      subject: "My Subject",
      text_body: "TEXT BODY",
      html_body: "HTML BODY",
    )
    |> Email.put_header("X-My-Header", "my_header_value")

    SparkPostAdapter.deliver(email, @config)

    assert_receive {:fake_sparkpost, %{params: params, req_headers: headers}}

    assert params["from"] == elem(email.from, 1)
    assert params["subject"] == email.subject
    assert params["text"] == email.text_body
    assert params["html"] == email.html_body
    assert params["h:X-My-Header"] == "my_header_value" 

    hashed_token = Base.encode64("api:" <> @config.api_key)

    assert {"authorization", "Basic #{hashed_token}"} in headers
  end

  test "deliver/2 correctly formats recipients" do
    email = new_email(
      to: [{"To", "to@bar.com"}, {nil, "noname@bar.com"}],
      cc: [{"CC", "cc@bar.com"}],
      bcc: [{"BCC", "bcc@bar.com"}],
    )

    email |> SparkPostAdapter.deliver(@config)
    assert_receive {:fake_spark_post, %{params: params}}
    assert params["to"] == ["To <to@bar.com>", "noname@bar.com"]
    assert params["cc"] == ["CC <cc@bar.com>"]
    assert params["bcc"] == ["BCC <bcc@bar.com>"]
  end

  test "raises if the response is not a success" do
    email = new_email(from: "INVALID_EMAIL")

    assert_raise SparkPostAdapter.ApiError, fn ->
      email |> SparkPostAdapter.deliver(@config)
    end
  end

  defp new_email(attrs \\ []) do
    attrs = Keyword.merge([from: "foo@bar.com", to: []], attrs)
    Email.new_email(attrs) |> Bamboo.Mailer.normalize_addresses
  end

end

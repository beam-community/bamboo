defmodule Bamboo.SendGridAdapterTest do
  use ExUnit.Case
  alias Bamboo.Email
  alias Bamboo.SendGridAdapter

  @config %{adapter: SendGridAdapter, api_key: "123_abc"}
  @config_with_bad_key %{adapter: SendGridAdapter, api_key: nil}

  defmodule FakeSendGrid do
    use Plug.Router

    plug Plug.Parsers,
      parsers: [:urlencoded, :multipart, :json],
      pass: ["*/*"],
      json_decoder: Poison
    plug :match
    plug :dispatch

    def start_server(parent) do
      Agent.start_link(fn -> HashDict.new end, name: __MODULE__)
      Agent.update(__MODULE__, &HashDict.put(&1, :parent, parent))
      port = get_free_port
      Application.put_env(:bamboo, :sendgrid_base_uri, "http://localhost:#{port}")
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

    post "/mail.send.json" do
      case Map.get(conn.params, "from") do
        "INVALID_EMAIL" -> conn |> send_resp(500, "Error!!") |> send_to_parent
        _ -> conn |> send_resp(200, "SENT") |> send_to_parent
      end
    end

    defp send_to_parent(conn) do
      parent = Agent.get(__MODULE__, fn(set) -> HashDict.get(set, :parent) end)
      send parent, {:fake_send_grid, conn}
      conn
    end
  end

  setup do
    FakeSendGrid.start_server(self)

    on_exit fn ->
      FakeSendGrid.shutdown
    end

    :ok
  end

  test "raises if the api key is nil" do
    assert_raise ArgumentError, ~r/no API key set/, fn ->
      new_email(from: "foo@bar.com") |> SendGridAdapter.deliver(@config_with_bad_key)
    end

    assert_raise ArgumentError, ~r/no API key set/, fn ->
      SendGridAdapter.handle_config(%{})
    end
  end

  test "deliver/2 sends the to the right url" do
    new_email |> SendGridAdapter.deliver(@config)

    assert_receive {:fake_send_grid, %{request_path: request_path}}

    assert request_path == "/mail.send.json"
  end

  test "deliver/2 sends from, html and text body, subject, and headers" do
    email = new_email(
      from: {"From", "from@foo.com"},
      subject: "My Subject",
      text_body: "TEXT BODY",
      html_body: "HTML BODY",
    )
    |> Email.put_header("Reply-To", "reply@foo.com")

    email |> SendGridAdapter.deliver(@config)

    assert_receive {:fake_send_grid, %{params: params, req_headers: headers}}

    assert params["fromname"] == email.from |> elem(0)
    assert params["from"] == email.from |> elem(1)
    assert params["subject"] == email.subject
    assert params["text"] == email.text_body
    assert params["html"] == email.html_body
    assert Enum.member?(headers, {"authorization", "Bearer #{@config[:api_key]}"})
  end

  test "deliver/2 correctly formats recipients" do
    email = new_email(
      to: [{"To", "to@bar.com"}, {nil, "noname@bar.com"}],
      cc: [{"CC", "cc@bar.com"}],
      bcc: [{"BCC", "bcc@bar.com"}],
    )

    email |> SendGridAdapter.deliver(@config)

    assert_receive {:fake_send_grid, %{params: params}}
    assert params["to"] == ["to@bar.com", "noname@bar.com"]
    assert params["toname"] == ["To", ""]
    assert params["cc"] == ["cc@bar.com"]
    assert params["ccname"] == ["CC"]
    assert params["bcc"] == ["bcc@bar.com"]
    assert params["bccname"] == ["BCC"]
  end

  test "raises if the response is not a success" do
    email = new_email(from: "INVALID_EMAIL")

    assert_raise Bamboo.SendGridAdapter.ApiError, fn ->
      email |> SendGridAdapter.deliver(@config)
    end
  end

  test "removes api key from error output" do
    email = new_email(from: "INVALID_EMAIL")

    assert_raise Bamboo.SendGridAdapter.ApiError, ~r/"key" => "\[FILTERED\]"/, fn ->
      email |> SendGridAdapter.deliver(@config)
    end
  end

  defp new_email(attrs \\ []) do
    attrs = Keyword.merge([from: "foo@bar.com", to: []], attrs)
    Email.new_email(attrs) |> Bamboo.Mailer.normalize_addresses
  end
end

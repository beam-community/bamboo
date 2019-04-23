defmodule Bamboo.CampaignMonitorAdapterTest do
  use ExUnit.Case
  alias Bamboo.Email
  alias Bamboo.CampaignMonitorAdapter

  @config %{adapter: CampaignMonitorAdapter, api_key: "123_abc", client_id: "client_123"}
  @config_with_bad_key %{adapter: CampaignMonitorAdapter, api_key: nil, client_id: nil}
  @config_with_env_var_key %{
    adapter: CampaignMonitorAdapter,
    api_key: {:system, "CAMPAIGN_MONITOR_API_KEY"},
    client_id: {:system, "CAMPAIGN_MONITOR_CLIENT_ID"}
  }

  defmodule FakeCampaignMonitor do
    use Plug.Router

    plug(
      Plug.Parsers,
      parsers: [:urlencoded, :multipart, :json],
      pass: ["*/*"],
      json_decoder: Poison
    )

    plug(:match)
    plug(:dispatch)

    def start_server(parent) do
      Agent.start_link(fn -> Map.new() end, name: __MODULE__)
      Agent.update(__MODULE__, &Map.put(&1, :parent, parent))
      port = get_free_port()
      Application.put_env(:bamboo, :campaign_monitor_base_uri, "http://localhost:#{port}")
      Plug.Adapters.Cowboy.http(__MODULE__, [], port: port, ref: __MODULE__)
    end

    defp get_free_port do
      {:ok, socket} = :ranch_tcp.listen(port: 0)
      {:ok, port} = :inet.port(socket)
      :erlang.port_close(socket)
      port
    end

    def shutdown do
      Plug.Adapters.Cowboy.shutdown(__MODULE__)
    end

    post "/transactional/classicEmail/send" do
      case get_in(conn.params, ["From"]) do
        "INVALID_EMAIL" -> conn |> send_resp(500, "Error!!") |> send_to_parent
        _ -> conn |> send_resp(200, "SENT") |> send_to_parent
      end
    end

    defp send_to_parent(conn) do
      parent = Agent.get(__MODULE__, fn set -> Map.get(set, :parent) end)
      send(parent, {:fake_campaign_monitor, conn})
      conn
    end
  end

  setup do
    FakeCampaignMonitor.start_server(self())

    on_exit(fn ->
      FakeCampaignMonitor.shutdown()
    end)

    :ok
  end

  test "raises if the api key is nil" do
    assert_raise ArgumentError, ~r/no API key set/, fn ->
      new_email(from: "foo@bar.com") |> CampaignMonitorAdapter.deliver(@config_with_bad_key)
    end

    assert_raise ArgumentError, ~r/no API key set/, fn ->
      CampaignMonitorAdapter.handle_config(%{})
    end
  end

  test "can read the api key from an ENV var" do
    System.put_env("CAMPAIGN_MONITOR_API_KEY", "123_abc")

    config = CampaignMonitorAdapter.handle_config(@config_with_env_var_key)

    assert config[:api_key] == "123_abc"
  end

  test "raises if an invalid ENV var is used for the API key" do
    System.delete_env("CAMPAIGN_MONITOR_API_KEY")

    assert_raise ArgumentError, ~r/no API key set/, fn ->
      new_email(from: "foo@bar.com") |> CampaignMonitorAdapter.deliver(@config_with_env_var_key)
    end

    assert_raise ArgumentError, ~r/no API key set/, fn ->
      CampaignMonitorAdapter.handle_config(@config_with_env_var_key)
    end
  end

  test "deliver/2 sends the to the right url" do
    new_email() |> CampaignMonitorAdapter.deliver(@config)

    assert_receive {:fake_campaign_monitor, %{request_path: request_path}}

    assert request_path == "/transactional/classicEmail/send"
  end

  test "deliver/2 sends from, html and text body, subject" do
    email =
      new_email(
        from: {"From", "from@foo.com"},
        subject: "My Subject",
        text_body: "TEXT BODY",
        html_body: "HTML BODY"
      )
      |> Email.put_header("Reply-To", "reply@foo.com")

    email |> CampaignMonitorAdapter.deliver(@config)

    refute CampaignMonitorAdapter.supports_attachments?()
    assert_receive {:fake_campaign_monitor, %{params: params, req_headers: headers}}

    assert params["From"] == "From <from@foo.com>"
    assert params["Subject"] == email.subject
    assert params["Text"] == email.text_body
    assert params["Html"] == email.html_body
  end

  test "deliver/2 correctly formats recipients" do
    email =
      new_email(
        to: [{"To", "to@bar.com"}, {nil, "noname@bar.com"}],
        cc: [{"CC", "cc@bar.com"}],
        bcc: [{"BCC", "bcc@bar.com"}]
      )

    email |> CampaignMonitorAdapter.deliver(@config)

    assert_receive {:fake_campaign_monitor, %{params: params}}

    assert params["To"] == ["To <to@bar.com>", "noname@bar.com"]
    assert params["BCC"] == ["BCC <bcc@bar.com>"]
    assert params["CC"] == ["CC <cc@bar.com>"]
  end

  test "deliver/2 doesn't force a subject" do
    email = new_email(from: {"From", "from@foo.com"})

    email
    |> CampaignMonitorAdapter.deliver(@config)

    assert_receive {:fake_campaign_monitor, %{params: params}}
    refute Map.has_key?(params, "subject")
  end

  test "deliver/2 correctly formats reply-to from headers" do
    email = new_email(headers: %{"reply-to" => "foo@bar.com"})

    email |> CampaignMonitorAdapter.deliver(@config)

    assert_receive {:fake_campaign_monitor, %{params: params}}
    assert params["ReplyTo"] == "foo@bar.com"
  end

  test "raises if the response is not a success" do
    email = new_email(from: "INVALID_EMAIL")

    assert_raise Bamboo.ApiError, fn ->
      email |> CampaignMonitorAdapter.deliver(@config)
    end
  end

  test "removes api key from error output" do
    email = new_email(from: "INVALID_EMAIL")

    assert_raise Bamboo.ApiError, ~r/"key" => "\[FILTERED\]"/, fn ->
      email |> CampaignMonitorAdapter.deliver(@config)
    end
  end

  defp new_email(attrs \\ []) do
    attrs = Keyword.merge([from: "foo@bar.com", to: []], attrs)
    Email.new_email(attrs) |> Bamboo.Mailer.normalize_addresses()
  end
end

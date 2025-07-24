defmodule Bamboo.MailgunAdapterTest do
  use ExUnit.Case
  alias Bamboo.Email
  alias Bamboo.MailgunAdapter

  @config %{adapter: MailgunAdapter, api_key: "dummyapikey", domain: "test.tt"}
  @config_with_env_var_key %{
    adapter: MailgunAdapter,
    api_key: {:system, "MAILGUN_API_KEY"},
    domain: {:system, "MAILGUN_DOMAIN"}
  }

  defmodule FakeMailgun do
    use Plug.Router

    alias Plug.Cowboy

    plug(
      Plug.Parsers,
      parsers: [:urlencoded, :multipart, :json],
      pass: ["*/*"],
      json_decoder: Jason
    )

    plug(:match)
    plug(:dispatch)

    def start_server(parent) do
      Agent.start_link(fn -> Map.new() end, name: __MODULE__)
      Agent.update(__MODULE__, &Map.put(&1, :parent, parent))
      port = get_free_port()
      Application.put_env(:bamboo, :mailgun_base_uri, "http://localhost:#{port}")
      Cowboy.http(__MODULE__, [], port: port, ref: __MODULE__)
    end

    defp get_free_port do
      {:ok, socket} = :ranch_tcp.listen(port: 0)
      {:ok, port} = :inet.port(socket)
      :erlang.port_close(socket)
      port
    end

    def shutdown do
      Cowboy.shutdown(__MODULE__)
    end

    post "/test.tt/messages" do
      conn =
        case Map.get(conn.params, "from") do
          "INVALID_EMAIL" ->
            send_resp(
              conn,
              500,
              "{\n \"message\": \"'from' parameter is not a valid address. please check documentation\"\n}"
            )

          _ ->
            send_resp(conn, 200, "SENT")
        end

      send_to_parent(conn)
    end

    defp send_to_parent(conn) do
      parent = Agent.get(__MODULE__, fn set -> Map.get(set, :parent) end)
      send(parent, {:fake_mailgun, conn})
      conn
    end
  end

  setup do
    FakeMailgun.start_server(self())

    on_exit(fn ->
      FakeMailgun.shutdown()
    end)

    :ok
  end

  test "can read the settings from an ENV var" do
    System.put_env("MAILGUN_API_KEY", "env_api_key")
    System.put_env("MAILGUN_DOMAIN", "env_domain")

    config = MailgunAdapter.handle_config(@config_with_env_var_key)

    assert config[:api_key] == "env_api_key"
    assert config[:domain] == "env_domain"

    System.delete_env("MAILGUN_API_KEY")
    System.delete_env("MAILGUN_DOMAIN")
  end

  test "raises if the api key is nil" do
    assert_raise ArgumentError, ~r/no api_key set/, fn ->
      MailgunAdapter.handle_config(%{domain: "test.tt"})
    end
  end

  test "raises if the domain is nil" do
    assert_raise ArgumentError, ~r/no domain set/, fn ->
      MailgunAdapter.handle_config(%{api_key: "dummyapikey"})
    end
  end

  test "raises if an invalid ENV var is used for the api_key" do
    System.put_env("MAILGUN_DOMAIN", "env_domain")

    assert_raise ArgumentError, ~r/no api_key set/, fn ->
      [from: "foo@bar.com"] |> new_email() |> MailgunAdapter.deliver(@config_with_env_var_key)
    end

    assert_raise ArgumentError, ~r/no api_key set/, fn ->
      MailgunAdapter.handle_config(@config_with_env_var_key)
    end

    System.delete_env("MAILGUN_DOMAIN")
  end

  test "raises if an invalid ENV var is used for the domain" do
    System.put_env("MAILGUN_API_KEY", "env_api_key")

    assert_raise ArgumentError, ~r/no domain set/, fn ->
      [from: "foo@bar.com"] |> new_email() |> MailgunAdapter.deliver(@config_with_env_var_key)
    end

    assert_raise ArgumentError, ~r/no domain set/, fn ->
      MailgunAdapter.handle_config(@config_with_env_var_key)
    end

    System.delete_env("MAILGUN_API_KEY")
  end

  test "see if default base_uri is set" do
    Application.delete_env(:bamboo, :mailgun_base_uri)

    assert MailgunAdapter.handle_config(%{
             api_key: "dummyapikey",
             domain: "test.tt"
           }).base_uri == "https://api.mailgun.net/v3"
  end

  test "see if given base_uri is set" do
    assert MailgunAdapter.handle_config(%{
             api_key: "dummyapikey",
             domain: "test.tt",
             base_uri: "https://api.eu.mailgun.net/v3"
           }).base_uri == "https://api.eu.mailgun.net/v3"
  end

  test "adapter-level base_uri overrules application env config" do
    Application.put_env(:bamboo, :mailgun_base_uri, "https://application")

    assert MailgunAdapter.handle_config(%{
             api_key: "dummyapikey",
             domain: "test.tt",
             base_uri: "https://adapter"
           }).base_uri == "https://adapter"
  end

  test "deliver/2 sends the to the right url" do
    MailgunAdapter.deliver(new_email(), @config)

    assert_receive {:fake_mailgun, %{request_path: request_path}}

    assert request_path == "/test.tt/messages"
  end

  test "deliver/2 returns an {:ok, response} tuple" do
    {:ok, response} = MailgunAdapter.deliver(new_email(), @config)

    assert %{status_code: 200, headers: _, body: _} = response
  end

  test "deliver/2 sends from, subject, text body, html body, headers, custom vars and recipient variables" do
    email =
      [from: "from@foo.com", subject: "My Subject", text_body: "TEXT BODY", html_body: "HTML BODY"]
      |> new_email()
      |> Email.put_header("X-My-Header", "my_header_value")
      |> Email.put_header("Reply-To", "random@foo.com")
      |> Email.put_private(:mailgun_custom_vars, %{my_custom_var: 42, other_custom_var: 43})
      |> Email.put_private(
        :mailgun_recipient_variables,
        "{\"user1@example.com\":{\"unique_id\":\"ABC123456789\"}}"
      )

    MailgunAdapter.deliver(email, @config)

    assert_receive {:fake_mailgun, %{params: params, req_headers: headers}}

    assert params["from"] == elem(email.from, 1)
    assert params["subject"] == email.subject
    assert params["text"] == email.text_body
    assert params["html"] == email.html_body
    assert params["h:X-My-Header"] == "my_header_value"
    assert params["v:my_custom_var"] == "42"
    assert params["v:other_custom_var"] == "43"
    assert params["h:Reply-To"] == "random@foo.com"

    assert params["recipient-variables"] ==
             "{\"user1@example.com\":{\"unique_id\":\"ABC123456789\"}}"

    hashed_token = Base.encode64("api:" <> @config.api_key)
    assert {"authorization", "Basic #{hashed_token}"} in headers
  end

  # We keep two separate tests, with and without attachment, because the output produced by the adapter changes a lot. (MIME multipart body instead of URL-encoded form)
  test "deliver/2 sends from, subject, text body, html body, headers, custom vars and attachment" do
    attachment_source_path = Path.join(__DIR__, "../../../support/attachment.txt")

    email =
      [from: "from@foo.com", subject: "My Subject", text_body: "TEXT BODY", html_body: "HTML BODY"]
      |> new_email()
      |> Email.put_header("Reply-To", "random@foo.com")
      |> Email.put_header("X-My-Header", "my_header_value")
      |> Email.put_private(:mailgun_custom_vars, %{my_custom_var: 42, other_custom_var: 43})
      |> Email.put_attachment(attachment_source_path)

    MailgunAdapter.deliver(email, @config)

    assert_receive {:fake_mailgun, %{params: params, req_headers: headers}}

    assert MailgunAdapter.supports_attachments?()
    assert params["from"] == elem(email.from, 1)
    assert params["subject"] == email.subject
    assert params["text"] == email.text_body
    assert params["html"] == email.html_body
    assert params["h:X-My-Header"] == "my_header_value"
    assert params["v:my_custom_var"] == "42"
    assert params["v:other_custom_var"] == "43"
    assert params["h:Reply-To"] == "random@foo.com"

    assert %Plug.Upload{content_type: content_type, filename: filename, path: download_path} =
             params["attachment"]

    assert content_type == "application/octet-stream"
    assert filename == "attachment.txt"
    assert File.read!(download_path) == File.read!(attachment_source_path)

    hashed_token = Base.encode64("api:" <> @config.api_key)
    assert {"authorization", "Basic #{hashed_token}"} in headers
  end

  test "deliver/2 correctly formats recipients" do
    email =
      new_email(
        to: [{"To", "to@bar.com"}, {nil, "noname@bar.com"}],
        cc: [{"CC", "cc@bar.com"}],
        bcc: [{"BCC", "bcc@bar.com"}]
      )

    MailgunAdapter.deliver(email, @config)

    assert_receive {:fake_mailgun, %{params: params}}
    assert params["to"] == "To <to@bar.com>,noname@bar.com"
    assert params["cc"] == "CC <cc@bar.com>"
    assert params["bcc"] == "BCC <bcc@bar.com>"
  end

  test "deliver/2 correctly formats reply-to" do
    email =
      [from: "from@foo.com", subject: "My Subject", text_body: "TEXT BODY", html_body: "HTML BODY"]
      |> new_email()
      |> Email.put_header("reply-to", "random@foo.com")

    MailgunAdapter.deliver(email, @config)

    assert_receive {:fake_mailgun, %{params: params}}

    assert params["h:Reply-To"] == "random@foo.com"
  end

  test "deliver/2 correctly formats template and template options" do
    email =
      [from: "from@foo.com", subject: "My Subject", text_body: "TEXT BODY", html_body: "HTML BODY"]
      |> new_email()
      |> Email.put_private(:template, "my_template")
      |> Email.put_private(:"t:version", "v2")
      |> Email.put_private(:"t:text", true)

    MailgunAdapter.deliver(email, @config)

    assert_receive {:fake_mailgun, %{params: params}}

    assert params["template"] == "my_template"
    assert params["t:version"] == "v2"
    assert params["t:text"] == "yes"
  end

  test "deliver/2 includes whitelisted o: options from private" do
    email =
      [from: "from@foo.com", subject: "My Subject", text_body: "TEXT BODY", html_body: "HTML BODY"]
      |> new_email()
      |> Email.put_private(:"o:tracking", "yes")
      |> Email.put_private(:"o:tracking-clicks", "htmlonly")
      |> Email.put_private(:"o:dkim", "yes")
      |> Email.put_private(:"o:testmode", "true")

    MailgunAdapter.deliver(email, @config)

    assert_receive {:fake_mailgun, %{params: params}}

    assert params["o:tracking"] == "yes"
    assert params["o:tracking-clicks"] == "htmlonly"
    assert params["o:dkim"] == "yes"
    assert params["o:testmode"] == "true"
  end

  test "deliver/2 ignores unsupported o: options from private" do
    email =
      [from: "from@foo.com", subject: "My Subject", text_body: "TEXT BODY", html_body: "HTML BODY"]
      |> new_email()
      |> Email.put_private(:"o:tracking", "yes")
      |> Email.put_private(:"o:unsupported-option", "value")
      |> Email.put_private(:"o:invalid", "should-be-ignored")

    MailgunAdapter.deliver(email, @config)

    assert_receive {:fake_mailgun, %{params: params}}

    # Supported option should be included
    assert params["o:tracking"] == "yes"

    # Unsupported options should be ignored
    refute Map.has_key?(params, "o:unsupported-option")
    refute Map.has_key?(params, "o:invalid")
  end

  test "deliver/2 works with all allowed o: options" do
    email =
      [from: "from@foo.com", subject: "My Subject", text_body: "TEXT BODY", html_body: "HTML BODY"]
      |> new_email()
      |> Email.put_private(:"o:tag", ["tag1", "tag2"])
      |> Email.put_private(:"o:deliverytime", "Wed, 15 Nov 2023 09:30:00 +0000")
      |> Email.put_private(:"o:tracking-opens", "yes")
      |> Email.put_private(:"o:require-tls", "true")
      |> Email.put_private(:"o:skip-verification", "false")
      |> Email.put_private(:"o:sending-ip", "192.168.1.1")
      |> Email.put_private(:"o:sending-ip-pool", "pool-123")
      |> Email.put_private(:"o:tracking-pixel-location-top", "yes")
      |> Email.put_private(:"o:secondary-dkim", "example.com/s1")
      |> Email.put_private(:"o:secondary-dkim-public", "public.com/s1")

    MailgunAdapter.deliver(email, @config)

    assert_receive {:fake_mailgun, %{params: params}}

    assert params["o:tag"] == ["tag1", "tag2"]
    assert params["o:deliverytime"] == "Wed, 15 Nov 2023 09:30:00 +0000"
    assert params["o:tracking-opens"] == "yes"
    assert params["o:require-tls"] == "true"
    assert params["o:skip-verification"] == "false"
    assert params["o:sending-ip"] == "192.168.1.1"
    assert params["o:sending-ip-pool"] == "pool-123"
    assert params["o:tracking-pixel-location-top"] == "yes"
    assert params["o:secondary-dkim"] == "example.com/s1"
    assert params["o:secondary-dkim-public"] == "public.com/s1"
  end

  test "returns an error if the response is not a success" do
    email = new_email(from: "INVALID_EMAIL")

    {:error, %Bamboo.ApiError{} = error} = MailgunAdapter.deliver(email, @config)

    assert error.message =~ ~r/.*%{.*\"from\" => \"INVALID_EMAIL\".*}/
  end

  test "returns an error if the response is not a success with attachment" do
    attachment_source_path = Path.join(__DIR__, "../../../support/attachment.txt")

    email =
      [from: "INVALID_EMAIL"]
      |> new_email()
      |> Email.put_attachment(attachment_source_path)

    {:error, %Bamboo.ApiError{} = error} = MailgunAdapter.deliver(email, @config)

    assert error.message =~ ~r/.*{.*\"from\", \"INVALID_EMAIL\".*}/
  end

  defp new_email(attrs \\ []) do
    [from: "foo@bar.com", to: []] |> Keyword.merge(attrs) |> Email.new_email() |> Bamboo.Mailer.normalize_addresses()
  end
end

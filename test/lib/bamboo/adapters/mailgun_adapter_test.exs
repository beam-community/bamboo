defmodule Bamboo.MailgunAdapterTest do
  use ExUnit.Case
  alias Bamboo.Email
  alias Bamboo.MailgunAdapter

  @config %{adapter: MailgunAdapter, api_key: "dummyapikey", domain: "test.tt"}

  defmodule FakeMailgun do
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
      Application.put_env(:bamboo, :mailgun_base_uri, "http://localhost:#{port}")
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

    post "/test.tt/messages" do
      case Map.get(conn.params, "from") do
        "INVALID_EMAIL" -> send_resp(conn, 500, "Error!!")
        _ -> send_resp(conn, 200, "SENT")
      end
      |> send_to_parent
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

  test "deliver/2 sends the to the right url" do
    new_email() |> MailgunAdapter.deliver(@config)

    assert_receive {:fake_mailgun, %{request_path: request_path}}

    assert request_path == "/test.tt/messages"
  end

  test "deliver/2 sends from, subject, text body, html body, headers and custom vars" do
    email =
      new_email(
        from: "from@foo.com",
        subject: "My Subject",
        text_body: "TEXT BODY",
        html_body: "HTML BODY"
      )
      |> Email.put_header("X-My-Header", "my_header_value")
      |> Email.put_header("Reply-To", "random@foo.com")
      |> Email.put_private(:mailgun_custom_vars, %{my_custom_var: 42, other_custom_var: 43})

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

    hashed_token = Base.encode64("api:" <> @config.api_key)
    assert {"authorization", "Basic #{hashed_token}"} in headers
  end

  # We keep two seperate tests, with and without attachment, because the output produced by the adapter changes a lot. (MIME multipart body instead of URL-encoded form)
  test "deliver/2 sends from, subject, text body, html body, headers, custom vars and attachment" do
    attachement_source_path = Path.join(__DIR__, "../../../support/attachment.txt")

    email =
      new_email(
        from: "from@foo.com",
        subject: "My Subject",
        text_body: "TEXT BODY",
        html_body: "HTML BODY"
      )
      |> Email.put_header("Reply-To", "random@foo.com")
      |> Email.put_header("X-My-Header", "my_header_value")
      |> Email.put_private(:mailgun_custom_vars, %{my_custom_var: 42, other_custom_var: 43})
      |> Email.put_attachment(attachement_source_path)

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
    assert File.read!(download_path) == File.read!(attachement_source_path)

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

    email |> MailgunAdapter.deliver(@config)

    assert_receive {:fake_mailgun, %{params: params}}
    assert params["to"] == "To <to@bar.com>,noname@bar.com"
    assert params["cc"] == "CC <cc@bar.com>"
    assert params["bcc"] == "BCC <bcc@bar.com>"
  end

  test "deliver/2 correctly formats reply-to" do
    email =
      new_email(
        from: "from@foo.com",
        subject: "My Subject",
        text_body: "TEXT BODY",
        html_body: "HTML BODY"
      )
      |> Email.put_header("reply-to", "random@foo.com")

    MailgunAdapter.deliver(email, @config)

    assert_receive {:fake_mailgun, %{params: params}}

    assert params["h:Reply-To"] == "random@foo.com"
  end

  test "returns error status if the response is not a success" do
    email = new_email(from: "INVALID_EMAIL")

    {:ok, %{status_code: 500, body: "Error!!"}} = MailgunAdapter.deliver(email, @config)
  end

  defp new_email(attrs \\ []) do
    attrs = Keyword.merge([from: "foo@bar.com", to: []], attrs)
    Email.new_email(attrs) |> Bamboo.Mailer.normalize_addresses()
  end
end

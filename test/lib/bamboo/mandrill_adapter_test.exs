defmodule Bamboo.MandrillAdapterTest do
  use ExUnit.Case
  alias Bamboo.Email
  alias Bamboo.MandrillEmail
  alias Bamboo.MandrillAdapter

  @config %{adapter: MandrillAdapter, api_key: "123_abc"}
  @config_with_bad_key %{adapter: MandrillAdapter, api_key: nil}

  defmodule FakeMandrill do
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
      Application.put_env(:bamboo, :mandrill_base_uri, "http://localhost:4001")
      Plug.Adapters.Cowboy.http __MODULE__, [], port: 4001
    end

    def shutdown do
      Plug.Adapters.Cowboy.shutdown __MODULE__
    end

    post "/api/1.0/messages/send.json" do
      case get_in(conn.params, ["message", "from_email"]) do
        "INVALID_EMAIL" -> conn |> send_resp(500, "Error!!") |> send_to_parent
        _ -> conn |> send_resp(200, "SENT") |> send_to_parent
      end
    end

    defp send_to_parent(conn) do
      parent = Agent.get(__MODULE__, fn(set) -> HashDict.get(set, :parent) end)
      send parent, {:fake_mandrill, conn}
      conn
    end
  end

  setup do
    FakeMandrill.start_server(self)

    on_exit fn ->
      FakeMandrill.shutdown
    end

    :ok
  end

  test "raises if the api key is nil" do
    assert_raise ArgumentError, ~r/no API key set/, fn ->
      new_email(from: "foo@bar.com") |> MandrillAdapter.deliver_now(@config_with_bad_key)
    end

    assert_raise ArgumentError, ~r/no API key set/, fn ->
      MandrillAdapter.handle_config(%{})
    end
  end

  test "deliver/2 sends the to the right url" do
    new_email |> MandrillAdapter.deliver_now(@config)

    assert_receive {:fake_mandrill, %{request_path: request_path}}

    assert request_path == "/api/1.0/messages/send.json"
  end

  test "deliver/2 sends from, html and text body, subject, and headers" do
    email = new_email(
      from: {"From", "from@foo.com"},
      subject: "My Subject",
      text_body: "TEXT BODY",
      html_body: "HTML BODY",
    )
    |> Email.put_header("Reply-To", "reply@foo.com")

    email |> MandrillAdapter.deliver_now(@config)

    assert_receive {:fake_mandrill, %{params: params}}
    assert params["key"] == @config[:api_key]
    message = params["message"]
    assert message["from_name"] == email.from |> elem(0)
    assert message["from_email"] == email.from |> elem(1)
    assert message["subject"] == email.subject
    assert message["text"] == email.text_body
    assert message["html"] == email.html_body
    assert message["headers"] == email.headers
  end

  test "deliver/2 correctly formats recipients" do
    email = new_email(
      to: [{"To", "to@bar.com"}],
      cc: [{"CC", "cc@bar.com"}],
      bcc: [{"BCC", "bcc@bar.com"}],
    )

    email |> MandrillAdapter.deliver_now(@config)

    assert_receive {:fake_mandrill, %{params: %{"message" => message}}}
    assert message["to"] == [
      %{"name" => "To", "email" => "to@bar.com", "type" => "to"},
      %{"name" => "CC", "email" => "cc@bar.com", "type" => "cc"},
      %{"name" => "BCC", "email" => "bcc@bar.com", "type" => "bcc"}
    ]
  end

  test "deliver/2 adds extra params to the message " do
    email = new_email |> MandrillEmail.put_param("important", true)

    email |> MandrillAdapter.deliver_now(@config)

    assert_receive {:fake_mandrill, %{params: %{"message" => message}}}
    assert message["important"] == true
  end

  test "raises if the response is not a success" do
    email = new_email(from: "INVALID_EMAIL")

    assert_raise Bamboo.MandrillAdapter.ApiError, fn ->
      email |> MandrillAdapter.deliver_now(@config)
    end
  end

  test "removes api key from error output" do
    email = new_email(from: "INVALID_EMAIL")

    assert_raise Bamboo.MandrillAdapter.ApiError, ~r/"key" => "\[FILTERED\]"/, fn ->
      email |> MandrillAdapter.deliver_now(@config)
    end
  end

  defp new_email(attrs \\ []) do
    attrs = Keyword.merge([from: "foo@bar.com", to: []], attrs)
    Email.new_email(attrs) |> Bamboo.Mailer.normalize_addresses
  end
end

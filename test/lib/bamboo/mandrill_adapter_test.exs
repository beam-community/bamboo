defmodule Bamboo.MandrillAdapterTest do
  use ExUnit.Case

  alias Bamboo.Email
  alias Bamboo.EmailAddress
  alias Bamboo.MandrillEmail
  alias Bamboo.MandrillAdapter

  @api_key "123_abc"

  Application.put_env(:bamboo, __MODULE__.MailerWithBadKey, adapter: MandrillAdapter, api_key: nil)

  defmodule MailerWithBadKey do
    use Bamboo.Mailer, otp_app: :bamboo
  end

  Application.put_env(:bamboo, __MODULE__.Mailer, adapter: MandrillAdapter, api_key: @api_key)

  defmodule Mailer do
    use Bamboo.Mailer, otp_app: :bamboo
  end

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
    {:ok, %{}}
  end

  test "raises if the api key is nil" do
    assert_raise ArgumentError, ~r/no API key set/, fn ->
      new_email(from: "foo@bar.com") |> MailerWithBadKey.deliver
    end
  end

  test "deliver/2 sends the to the right url" do
    new_email |> Mailer.deliver

    assert_receive {:fake_mandrill, %{request_path: request_path}}

    assert request_path == "/api/1.0/messages/send.json"
  end

  test "deliver/2 sends from, html and text body, subject, and headers" do
    email = new_email(
      from: %EmailAddress{name: "From", address: "from@foo.com"},
      subject: "My Subject",
      text_body: "TEXT BODY",
      html_body: "HTML BODY",
    )
    |> Email.put_header("Reply-To", "reply@foo.com")

    email |> Mailer.deliver

    assert_receive {:fake_mandrill, %{params: params}}
    assert params["key"] == @api_key
    message = params["message"]
    assert message["from_email"] == email.from.address
    assert message["from_name"] == email.from.name
    assert message["subject"] == email.subject
    assert message["text"] == email.text_body
    assert message["html"] == email.html_body
    assert message["headers"] == email.headers
  end

  test "deliver_later sends asynchronously and can be awaited upon" do
    email = new_email(
      from: %EmailAddress{name: "From", address: "from@foo.com"},
      subject: "My Subject",
      text_body: "TEXT BODY",
      html_body: "HTML BODY",
    )
    |> Email.put_header("Reply-To", "reply@foo.com")

    task = email |> Mailer.deliver_later

    Task.await(task)
    assert_receive {:fake_mandrill, %{params: params}}
    assert params["key"] == @api_key
    message = params["message"]
    assert message["from_email"] == email.from.address
    assert message["from_name"] == email.from.name
    assert message["subject"] == email.subject
    assert message["text"] == email.text_body
    assert message["html"] == email.html_body
    assert message["headers"] == email.headers
  end

  test "deliver/2 correctly formats recipients" do
    email = new_email(
      to: [%EmailAddress{name: "To", address: "to@bar.com"}],
      cc: [%EmailAddress{name: "CC", address: "cc@bar.com"}],
      bcc: [%EmailAddress{name: "BCC", address: "bcc@bar.com"}],
    )

    email |> Mailer.deliver

    assert_receive {:fake_mandrill, %{params: %{"message" => message}}}
    assert message["to"] == [
      %{"name" => "To", "email" => "to@bar.com", "type" => "to"},
      %{"name" => "CC", "email" => "cc@bar.com", "type" => "cc"},
      %{"name" => "BCC", "email" => "bcc@bar.com", "type" => "bcc"}
    ]
  end

  test "deliver/2 adds extra params to the message " do
    email = new_email |> MandrillEmail.put_param("important", true)

    email |> Mailer.deliver

    assert_receive {:fake_mandrill, %{params: %{"message" => message}}}
    assert message["important"] == true
  end

  test "raises if the response is not a success" do
    email = new_email(from: "INVALID_EMAIL")

    assert_raise Bamboo.MandrillAdapter.ApiError, fn ->
      email |> Mailer.deliver
    end
  end

  defp new_email(attrs \\ []) do
    attrs = Keyword.merge([from: "foo@bar.com", to: []], attrs)
    Email.new_email(attrs)
  end
end

defmodule Bamboo.MandrillAdapterTest do
  use ExUnit.Case

  alias Bamboo.Email
  alias Bamboo.MandrillEmail
  import Bamboo.Email, only: [new_email: 1, new_email: 0]
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
      base_email |> MailerWithBadKey.deliver
    end
  end

  test "does not send the email if there are no recipients" do
    {:no_recipients, _} = new_email(to: [], cc: [], bcc: []) |> Mailer.deliver
    refute_received {:fake_mandrill, _}

    email_task = new_email(to: [], cc: [], bcc: []) |> Mailer.deliver_async
    {:no_recipients, _} = Task.await(email_task)
    refute_received {:fake_mandrill, _}
  end

  test "deliver/2 sends the to the right url" do
    base_email |> Mailer.deliver

    assert_receive {:fake_mandrill, %{request_path: request_path}}

    assert request_path == "/api/1.0/messages/send.json"
  end

  test "deliver/2 sends from, html and text body, subject, and headers" do
    email = base_email(
      from: %{name: "From", address: "from@foo.com"},
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

  test "deliver_async sends asynchronously and can be awaited upon" do
    email = base_email(
      from: %{name: "From", address: "from@foo.com"},
      subject: "My Subject",
      text_body: "TEXT BODY",
      html_body: "HTML BODY",
    )
    |> Email.put_header("Reply-To", "reply@foo.com")

    task = email |> Mailer.deliver_async

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
      to: [%{name: "To", address: "to@bar.com"}],
      cc: [%{name: "CC", address: "cc@bar.com"}],
      bcc: [%{name: "BCC", address: "bcc@bar.com"}],
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
    email = base_email |> MandrillEmail.put_message_param("important", true)

    email |> Mailer.deliver

    assert_receive {:fake_mandrill, %{params: %{"message" => message}}}
    assert message["important"] == true
  end

  test "raises if the response is not a success" do
    email = base_email(from: "INVALID_EMAIL")

    assert_raise Bamboo.MandrillAdapter.ApiError, fn ->
      email |> Mailer.deliver
    end
  end

  def base_email(attrs \\ []) do
    new_email(to: "foo@bar.com") |> struct(attrs)
  end
end

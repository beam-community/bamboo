defmodule Bamboo.MandrillAdapterTest do
  use ExUnit.Case

  alias Bamboo.Email
  import Bamboo.Email, only: [new_email: 1, new_email: 0]
  alias Bamboo.MandrillAdapter

  @api_key "123_abc"

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
      Plug.Adapters.Cowboy.http __MODULE__, [], port: 4001
    end

    post "/api/1.0/messages/send.json" do
      conn |> send_resp(200, "SENT") |> send_to_parent
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

  test "deliver/2 sends the to the right url" do
    new_email |> Mailer.deliver

    assert_receive {:fake_mandrill, %{request_path: request_path}}

    assert request_path == "/api/1.0/messages/send.json"
  end

  test "deliver/2 sends from, html and text body, subject, and headers" do
    email = new_email(
      from: %{name: "From", address: "from@foo.com"},
      subject: "My Subject",
      text_body: "TEXT BODY",
      html_body: "HTML BODY",
    )
    |> Email.put_header("Reply-To", "reply@foo.com")

    email |> Mailer.deliver

    assert_receive {:fake_mandrill, %{params: params}}
    assert params["api_key"] == @api_key
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
end

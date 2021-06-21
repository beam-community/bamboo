defmodule Bamboo.MandrillAdapterTest do
  use ExUnit.Case
  alias Bamboo.Attachment
  alias Bamboo.Email
  alias Bamboo.MandrillHelper
  alias Bamboo.MandrillAdapter

  @config %{adapter: MandrillAdapter, api_key: "123_abc"}
  @config_with_bad_key %{adapter: MandrillAdapter, api_key: nil}

  defmodule FakeMandrill do
    use Plug.Router

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
      Application.put_env(:bamboo, :mandrill_base_uri, "http://localhost:#{port}")
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

    post "/api/1.0/messages/send.json" do
      case get_in(conn.params, ["message", "from_email"]) do
        "INVALID_EMAIL" -> conn |> send_resp(500, "Error!!") |> send_to_parent
        _ -> conn |> send_resp(200, "SENT") |> send_to_parent
      end
    end

    post "/api/1.0/messages/send-template.json" do
      case get_in(conn.params, ["message", "from_email"]) do
        "INVALID_EMAIL" -> conn |> send_resp(500, "Error!!") |> send_to_parent
        _ -> conn |> send_resp(200, "SENT") |> send_to_parent
      end
    end

    defp send_to_parent(conn) do
      parent = Agent.get(__MODULE__, fn set -> Map.get(set, :parent) end)
      send(parent, {:fake_mandrill, conn})
      conn
    end
  end

  setup do
    FakeMandrill.start_server(self())

    on_exit(fn ->
      FakeMandrill.shutdown()
    end)

    :ok
  end

  test "raises if the api key is nil" do
    assert_raise ArgumentError, ~r/no API key set/, fn ->
      new_email(from: "foo@bar.com") |> MandrillAdapter.deliver(@config_with_bad_key)
    end

    assert_raise ArgumentError, ~r/no API key set/, fn ->
      MandrillAdapter.handle_config(%{})
    end
  end

  test "deliver/2 sends the to the right url" do
    new_email() |> MandrillAdapter.deliver(@config)

    assert_receive {:fake_mandrill, %{request_path: request_path}}

    assert request_path == "/api/1.0/messages/send.json"
  end

  test "deliver/2 returns an {:ok, response} tuple on success" do
    {:ok, response} = new_email() |> MandrillAdapter.deliver(@config)

    assert %{status_code: 200, headers: _, body: _} = response
  end

  test "deliver/2 sends the to the right url for templates" do
    new_email() |> MandrillHelper.template("hello") |> MandrillAdapter.deliver(@config)

    assert_receive {:fake_mandrill, %{request_path: request_path}}

    assert request_path == "/api/1.0/messages/send-template.json"
  end

  test "deliver/2 sends from, html and text body, subject, headers and attachment" do
    file_path = Path.join(__DIR__, "../../../support/attachment.txt")

    email =
      new_email(
        from: {"From", "from@foo.com"},
        subject: "My Subject",
        text_body: "TEXT BODY",
        html_body: "HTML BODY"
      )
      |> Email.put_header("Reply-To", "reply@foo.com")
      |> Email.put_attachment(file_path)
      |> Email.put_attachment(
        Attachment.new(file_path, content_id: "my_fake_image", filename: "fake_image.jpg")
      )
      |> Email.put_attachment(%Attachment{
        content_type: "image/png",
        content_id: "my_image",
        filename: "my_image.png",
        data:
          <<137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 0, 1, 0, 0, 0, 1,
            8, 6, 0, 0, 0, 31, 21, 196, 137, 0, 0, 0, 13, 73, 68, 65, 84, 120, 218, 99, 252, 207,
            192, 80, 15, 0, 4, 133, 1, 128, 132, 169, 140, 33, 0, 0, 0, 0, 73, 69, 78, 68, 174,
            66, 96, 130>>
      })

    email |> MandrillAdapter.deliver(@config)

    assert MandrillAdapter.supports_attachments?()
    assert_receive {:fake_mandrill, %{params: params}}
    assert params["key"] == @config[:api_key]
    message = params["message"]
    assert message["from_name"] == email.from |> elem(0)
    assert message["from_email"] == email.from |> elem(1)
    assert message["subject"] == email.subject
    assert message["text"] == email.text_body
    assert message["html"] == email.html_body
    assert message["headers"] == email.headers

    assert message["attachments"] == [
             %{
               "type" => "text/plain",
               "name" => "attachment.txt",
               "content" => "VGVzdCBBdHRhY2htZW50Cg=="
             },
             %{
               "type" => "text/plain",
               "name" => "fake_image.jpg",
               "content" => "VGVzdCBBdHRhY2htZW50Cg=="
             }
           ]

    assert message["images"] == [
             %{
               "type" => "image/png",
               "name" => "my_image",
               "content" =>
                 "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="
             }
           ]
  end

  test "deliver/2 correctly formats recipients" do
    email =
      new_email(
        to: [{"To", "to@bar.com"}],
        cc: [{"CC", "cc@bar.com"}],
        bcc: [{"BCC", "bcc@bar.com"}]
      )

    email |> MandrillAdapter.deliver(@config)

    assert_receive {:fake_mandrill, %{params: %{"message" => message}}}

    assert message["to"] == [
             %{"name" => "To", "email" => "to@bar.com", "type" => "to"},
             %{"name" => "CC", "email" => "cc@bar.com", "type" => "cc"},
             %{"name" => "BCC", "email" => "bcc@bar.com", "type" => "bcc"}
           ]
  end

  test "deliver/2 adds extra params to the message " do
    email = new_email() |> MandrillHelper.put_param("important", true)

    email |> MandrillAdapter.deliver(@config)

    assert_receive {:fake_mandrill, %{params: %{"message" => message}}}
    assert message["important"] == true
  end

  test "deliver/2 puts template name and empty content" do
    email = new_email() |> MandrillHelper.template("hello")

    email |> MandrillAdapter.deliver(@config)

    assert_receive {:fake_mandrill,
                    %{
                      params: %{
                        "template_name" => template_name,
                        "template_content" => template_content
                      }
                    }}

    assert template_name == "hello"
    assert template_content == []
  end

  test "deliver/2 puts template name and content" do
    email =
      new_email()
      |> MandrillHelper.template("hello", [
        %{name: 'example name', content: 'example content'}
      ])

    email |> MandrillAdapter.deliver(@config)

    assert_receive {:fake_mandrill,
                    %{
                      params: %{
                        "template_name" => template_name,
                        "template_content" => template_content
                      }
                    }}

    assert template_name == "hello"
    assert template_content == [%{"content" => 'example content', "name" => 'example name'}]
  end

  test "returns an error if the response is not a success" do
    email = new_email(from: "INVALID_EMAIL")

    {:error, error} = email |> MandrillAdapter.deliver(@config)

    assert %Bamboo.ApiError{} = error
  end

  test "removes api key from error output" do
    email = new_email(from: "INVALID_EMAIL")

    {:error, error} = email |> MandrillAdapter.deliver(@config)

    assert error.message =~ ~r/"key" => "\[FILTERED\]"/
  end

  defp new_email(attrs \\ []) do
    attrs = Keyword.merge([from: "foo@bar.com", to: []], attrs)
    Email.new_email(attrs) |> Bamboo.Mailer.normalize_addresses()
  end
end

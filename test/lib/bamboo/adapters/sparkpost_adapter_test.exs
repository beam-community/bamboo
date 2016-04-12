defmodule Bamboo.SparkpostAdapterTest do
  use ExUnit.Case
  alias Bamboo.Email
  alias Bamboo.SparkpostAdapter

  @config %{adapter: SparkpostAdapter, api_key: "123_abc"}
  @config_with_bad_key %{adapter: SparkpostAdapter, api_key: nil}

  defmodule FakeSparkpost do
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
      Plug.Adapters.Cowboy.http __MODULE__, [], port: 4001, ref: __MODULE__
    end

    def shutdown do
      Plug.Adapters.Cowboy.shutdown __MODULE__
    end

    post "/api/v1/transmissions" do
      case get_in(conn.params, ["content", "from", "email"]) do
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
    FakeSparkpost.start_server(self)

    on_exit fn ->
      FakeSparkpost.shutdown
    end

    :ok
  end

  test "raises if the api key is nil" do
    assert_raise ArgumentError, ~r/no API key set/, fn ->
      new_email(from: "foo@bar.com") |> SparkpostAdapter.deliver(@config_with_bad_key)
    end

    assert_raise ArgumentError, ~r/no API key set/, fn ->
      SparkpostAdapter.handle_config(%{})
    end
  end

  test "deliver/2 sends the to the right url" do
    new_email |> SparkpostAdapter.deliver(@config)

    assert_receive {:fake_mandrill, %{request_path: request_path}}

    assert request_path == "/api/v1/transmissions"
  end

  test "deliver/2 sends from, html and text body, subject, reply_to, and headers" do
    email = new_email(
      from: {"From", "from@foo.com"},
      subject: "My Subject",
      text_body: "TEXT BODY",
      html_body: "HTML BODY",
    )
    |> Email.put_header("Reply-To", "reply@foo.com")

    email |> SparkpostAdapter.deliver(@config)

    assert_receive {:fake_mandrill, %{params: params}=conn}
    assert Plug.Conn.get_req_header(conn, "content-type") == ["application/json"]
    assert Plug.Conn.get_req_header(conn, "authorization") == [@config[:api_key]]

    message = params["content"]
    assert message["from"]["name"] == email.from |> elem(0)
    assert message["from"]["email"] == email.from |> elem(1)
    assert message["subject"] == email.subject
    assert message["text"] == email.text_body
    assert message["html"] == email.html_body
    assert message["headers"] == %{}
    assert message["reply_to"] == "reply@foo.com"
  end

  test "deliver/2 correctly formats recipients" do
    email = new_email(
      to: [{"To", "to@bar.com"}],
      cc: [{"CC", "cc@bar.com"}],
      bcc: [{"BCC", "bcc@bar.com"}],
    )

    email |> SparkpostAdapter.deliver(@config)

    assert_receive {:fake_mandrill, %{params: %{"recipients" => recipients, "content" => %{"headers" => headers}}}}
    assert recipients == [
      %{"address" => %{"name" => "To", "email" => "to@bar.com"}},
      %{"address" => %{"name" => "CC", "email" => "cc@bar.com", "header_to" => "to@bar.com"}},
      %{"address" => %{"name" => "BCC", "email" => "bcc@bar.com", "header_to" => "to@bar.com"}},
    ]
    assert headers["CC"] == "cc@bar.com"
  end

  test "raises if the response is not a success" do
    email = new_email(from: "INVALID_EMAIL")

    assert_raise Bamboo.SparkpostAdapter.ApiError, fn ->
      email |> SparkpostAdapter.deliver(@config)
    end
  end

  test "removes api key from error output" do
    email = new_email(from: "INVALID_EMAIL")

    assert_raise Bamboo.SparkpostAdapter.ApiError, ~r/"key" => "\[FILTERED\]"/, fn ->
      email |> SparkpostAdapter.deliver(@config)
    end
  end

  defp new_email(attrs \\ []) do
    attrs = Keyword.merge([from: "foo@bar.com", to: []], attrs)
    Email.new_email(attrs) |> Bamboo.Mailer.normalize_addresses
  end
end

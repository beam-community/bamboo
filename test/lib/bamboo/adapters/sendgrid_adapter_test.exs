defmodule Bamboo.SendgridAdapterTest do
  use ExUnit.Case
  alias Bamboo.Email
  alias Bamboo.SendgridAdapter
  alias Bamboo.FakeEndpoint

  @config %{adapter: SendgridAdapter, api_key: "123_abc"}
  @config_with_bad_key %{adapter: SendgridAdapter, api_key: nil}

  setup do
    FakeEndpoint.start_server
    FakeEndpoint.register(self(), %{
      name: "sendgrid",
      params_path: ["from"],
      request_path: "/mail.send.json"
    })

    :ok
  end

  test "raises if the api key is nil" do
    assert_raise ArgumentError, ~r/no API key set/, fn ->
      new_email(from: "foo@bar.com") |> SendgridAdapter.deliver(@config_with_bad_key)
    end

    assert_raise ArgumentError, ~r/no API key set/, fn ->
      SendgridAdapter.handle_config(%{})
    end
  end

  test "deliver/2 sends the to the right url" do
    new_email |> SendgridAdapter.deliver(@config)

    assert_receive {:fake_endpoint, %{request_path: request_path}}

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

    email |> SendgridAdapter.deliver(@config)

    assert_receive {:fake_endpoint, %{params: params, req_headers: headers}}

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

    email |> SendgridAdapter.deliver(@config)

    assert_receive {:fake_endpoint, %{params: params}}
    assert params["to"] == ["to@bar.com", "noname@bar.com"]
    assert params["toname"] == ["To", ""]
    assert params["cc"] == ["cc@bar.com"]
    assert params["ccname"] == ["CC"]
    assert params["bcc"] == ["bcc@bar.com"]
    assert params["bccname"] == ["BCC"]
  end

  test "raises if the response is not a success" do
    email = new_email(from: "INVALID_EMAIL")

    assert_raise Bamboo.SendgridAdapter.ApiError, fn ->
      email |> SendgridAdapter.deliver(@config)
    end
  end

  test "removes api key from error output" do
    email = new_email(from: "INVALID_EMAIL")

    assert_raise Bamboo.SendgridAdapter.ApiError, ~r/"key" => "\[FILTERED\]"/, fn ->
      email |> SendgridAdapter.deliver(@config)
    end
  end

  defp new_email(attrs \\ []) do
    attrs = Keyword.merge([from: "foo@bar.com", to: []], attrs)
    Email.new_email(attrs) |> Bamboo.Mailer.normalize_addresses
  end
end

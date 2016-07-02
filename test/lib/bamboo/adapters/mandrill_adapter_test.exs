defmodule Bamboo.MandrillAdapterTest do
  use ExUnit.Case
  alias Bamboo.Email
  alias Bamboo.MandrillHelper
  alias Bamboo.MandrillAdapter
  alias Bamboo.FakeEndpoint

  @config %{adapter: MandrillAdapter, api_key: "123_abc"}
  @config_with_bad_key %{adapter: MandrillAdapter, api_key: nil}

  setup do
    FakeEndpoint.start_server
    FakeEndpoint.register(self(), %{
      name: "mandrill",
      params_path: ["message", "from_email"],
      request_path: [
        "/api/1.0/messages/send.json",
        "/api/1.0/messages/send-template.json"
      ]
    })

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
    new_email |> MandrillAdapter.deliver(@config)

    assert_receive {:fake_endpoint, %{request_path: request_path}}

    assert request_path == "/api/1.0/messages/send.json"
  end

  test "deliver/2 sends the to the right url for templates" do
    new_email |> MandrillHelper.template("hello") |> MandrillAdapter.deliver(@config)

    assert_receive {:fake_endpoint, %{request_path: request_path}}

    assert request_path == "/api/1.0/messages/send-template.json"
  end

  test "deliver/2 sends from, html and text body, subject, and headers" do
    email = new_email(
      from: {"From", "from@foo.com"},
      subject: "My Subject",
      text_body: "TEXT BODY",
      html_body: "HTML BODY",
    )
    |> Email.put_header("Reply-To", "reply@foo.com")

    email |> MandrillAdapter.deliver(@config)

    assert_receive {:fake_endpoint, %{params: params}}
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

    email |> MandrillAdapter.deliver(@config)

    assert_receive {:fake_endpoint, %{params: %{"message" => message}}}
    assert message["to"] == [
      %{"name" => "To", "email" => "to@bar.com", "type" => "to"},
      %{"name" => "CC", "email" => "cc@bar.com", "type" => "cc"},
      %{"name" => "BCC", "email" => "bcc@bar.com", "type" => "bcc"}
    ]
  end

  test "deliver/2 adds extra params to the message " do
    email = new_email |> MandrillHelper.put_param("important", true)

    email |> MandrillAdapter.deliver(@config)

    assert_receive {:fake_endpoint, %{params: %{"message" => message}}}
    assert message["important"] == true
  end

  test "deliver/2 puts template name and empty content" do
    email = new_email |> MandrillHelper.template("hello")

    email |> MandrillAdapter.deliver(@config)

    assert_receive {:fake_endpoint, %{params: %{"template_name" => template_name, "template_content" => template_content}}}
    assert template_name == "hello"
    assert template_content == []
  end

  test "deliver/2 puts template name and content" do
    email = new_email |> MandrillHelper.template("hello", [
      %{name: 'example name', content: 'example content'}
    ])

    email |> MandrillAdapter.deliver(@config)

    assert_receive {:fake_endpoint, %{params: %{"template_name" => template_name, "template_content" => template_content}}}
    assert template_name == "hello"
    assert template_content == [%{"content" => 'example content', "name" => 'example name'}]
  end

  test "raises if the response is not a success" do
    email = new_email(from: "INVALID_EMAIL")

    assert_raise Bamboo.MandrillAdapter.ApiError, fn ->
      email |> MandrillAdapter.deliver(@config)
    end
  end

  test "removes api key from error output" do
    email = new_email(from: "INVALID_EMAIL")

    assert_raise Bamboo.MandrillAdapter.ApiError, ~r/"key" => "\[FILTERED\]"/, fn ->
      email |> MandrillAdapter.deliver(@config)
    end
  end

  defp new_email(attrs \\ []) do
    attrs = Keyword.merge([from: "foo@bar.com", to: []], attrs)
    Email.new_email(attrs) |> Bamboo.Mailer.normalize_addresses
  end
end

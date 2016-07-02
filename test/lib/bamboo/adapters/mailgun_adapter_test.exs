defmodule Bamboo.MailgunAdapterTest do
  use ExUnit.Case
  alias Bamboo.Email
  alias Bamboo.MailgunAdapter
  alias Bamboo.FakeEndpoint

  @config %{adapter: MailgunAdapter, api_key: "dummyapikey", domain: "test.tt"}
  @config_with_bad_key %{@config | api_key: nil}
  @config_with_bad_domain %{@config | domain: nil}

  setup do
    FakeEndpoint.start_server
    FakeEndpoint.register("mailgun", self())

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
    new_email |> MailgunAdapter.deliver(@config)

    assert_receive {:fake_endpoint, %{request_path: request_path}}

    assert request_path == "/test.tt/messages"
  end

  test "deliver/2 sends from, html and text body, subject, and headers" do
    email = new_email(
      from: "from@foo.com",
      subject: "My Subject",
      text_body: "TEXT BODY",
      html_body: "HTML BODY",
    )

    MailgunAdapter.deliver(email, @config)

    assert_receive {:fake_endpoint, %{params: params, req_headers: headers}}

    assert params["from"] == elem(email.from, 1)
    assert params["subject"] == email.subject
    assert params["text"] == email.text_body
    assert params["html"] == email.html_body

    hashed_token  = Base.encode64("api:" <> @config.api_key)

    assert {"authorization", "Basic #{hashed_token}"} in headers
  end

  test "deliver/2 correctly formats recipients" do
    email = new_email(
      to: [{"To", "to@bar.com"}, {nil, "noname@bar.com"}],
      cc: [{"CC", "cc@bar.com"}],
      bcc: [{"BCC", "bcc@bar.com"}],
    )

    email |> MailgunAdapter.deliver(@config)

    assert_receive {:fake_endpoint, %{params: params}}
    assert params["to"] == ["To <to@bar.com>", "noname@bar.com"]
    assert params["cc"] == ["CC <cc@bar.com>"]
    assert params["bcc"] == ["BCC <bcc@bar.com>"]
  end

  test "raises if the response is not a success" do
    email = new_email(from: "INVALID_EMAIL")

    assert_raise MailgunAdapter.ApiError, fn ->
      email |> MailgunAdapter.deliver(@config)
    end
  end

  defp new_email(attrs \\ []) do
    attrs = Keyword.merge([from: "foo@bar.com", to: []], attrs)
    Email.new_email(attrs) |> Bamboo.Mailer.normalize_addresses
  end
end

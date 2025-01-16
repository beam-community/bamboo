defmodule Bamboo.SentEmailApiPlugTest do
  use ExUnit.Case
  use Plug.Test
  import Bamboo.Factory
  alias Bamboo.SentEmail

  defmodule AppRouter do
    use Plug.Router

    plug(:match)
    plug(:dispatch)

    forward("/", to: Bamboo.SentEmailApiPlug)
  end

  setup do
    SentEmail.reset()
    :ok
  end

  test "list emails over API" do
    normalize_and_push(:html_email,
      from: "from@example.com",
      to: ["to@example.com", {"Alice", "alice@example.com"}],
      cc: "cc@example.com",
      bcc: {"Bob", "bob@example.com"},
      subject: "This is a test email",
      html_body: "<p>hello world</p>",
      text_body: "hello world"
    )

    conn = :get |> conn("/emails.json") |> AppRouter.call(nil)

    assert conn.status == 200
    assert {"content-type", "application/json; charset=utf-8"} in conn.resp_headers

    json = Bamboo.json_library().decode!(conn.resp_body)

    assert Enum.count(json) == 1

    first_email = Enum.at(json, 0)
    assert first_email["from"] == [nil, "from@example.com"]
    assert first_email["to"] == [[nil, "to@example.com"], ["Alice", "alice@example.com"]]
    assert first_email["cc"] == [[nil, "cc@example.com"]]
    assert first_email["bcc"] == [["Bob", "bob@example.com"]]
    assert first_email["subject"] == "This is a test email"
    assert first_email["html_body"] == "<p>hello world</p>"
    assert first_email["text_body"] == "hello world"
    assert first_email["headers"] == %{}
  end

  test "reset emails over API" do
    normalize_and_push(:html_email)
    assert Enum.count(SentEmail.all()) == 1

    conn = :post |> conn("/reset.json") |> AppRouter.call(nil)

    assert conn.status == 200
    assert {"content-type", "application/json; charset=utf-8"} in conn.resp_headers

    json = Bamboo.json_library().decode!(conn.resp_body)
    assert json == %{"ok" => true}
    assert Enum.empty?(SentEmail.all())
  end
end

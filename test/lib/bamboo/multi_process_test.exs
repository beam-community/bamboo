defmodule Bamboo.MultiProcessTest do
  use ExUnit.Case
  use Bamboo.Test, shared: true
  import Bamboo.Email

  Application.put_env(
    :bamboo,
    __MODULE__.TestMailer,
    adapter: Bamboo.TestAdapter
  )

  defmodule TestMailer do
    use Bamboo.Mailer, otp_app: :bamboo
  end

  test "works when delivering emails from another process" do
    email = new_email(from: "jill@gmail.com", to: "bob@gmail.com")

    Task.async fn ->
      TestMailer.deliver_now(email)
    end

    assert_delivered_email email
  end

  test "refute_delivered_email with shared mode and with refute_timeout blank, raises an error" do
    assert_raise RuntimeError, ~r/set a timeout/, fn ->
      refute_delivered_email new_email(from: "someone")
    end
  end

  test "assert_no_emails_delivered with shared mode and with refute_timeout blank, raises an error" do
    assert_raise RuntimeError, ~r/set a timeout/, fn ->
      assert_no_emails_delivered()
    end
  end
end

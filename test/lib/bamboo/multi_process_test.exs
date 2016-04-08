defmodule Bamboo.MultiProcessTest do
  use ExUnit.Case
  use Bamboo.Test, process_name: :multi_process_test
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
end

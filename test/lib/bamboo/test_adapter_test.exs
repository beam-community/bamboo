defmodule Bamboo.TestAdapterTest do
  use ExUnit.Case
  use Bamboo.Test

  import Bamboo.Email, only: [new_email: 0, new_email: 1]

  @mailer_config adapter: Bamboo.TestAdapter

  Application.put_env(:bamboo, __MODULE__.TestMailer, @mailer_config)

  defmodule TestMailer do
    use Bamboo.Mailer, otp_app: :bamboo
  end

  test "deliver/2 sends a message to the process" do
    email = new_normalized_email(subject: "This is my email")

    email |> TestMailer.deliver

    assert_received {:delivered_email, ^email}
  end

  test "deliver_async/2 sends a message to the process and returns a Task" do
    email = new_normalized_email(subject: "This is my email")

    task = email |> TestMailer.deliver_async

    Task.await(task)
    assert_received {:delivered_email, ^email}
  end

  defp new_normalized_email(attrs) do
    attrs = attrs |> Keyword.put(:from, "foo@bar.com")
    new_email(attrs) |> Bamboo.Mailer.normalize_addresses
  end
end

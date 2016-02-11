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
    email = new_normalized_email()

    email |> TestMailer.deliver

    assert_received {:delivered_email, ^email}
  end

  test "deliver_later/2 sends a message to the process and returns a Task" do
    email = new_normalized_email()

    task = email |> TestMailer.deliver_later

    Task.await(task)
    assert_received {:delivered_email, ^email}
  end

  test "assertion helpers" do
    sent_email = new_email(from: "foo@bar.com")
    unsent_email = new_email(from: "foo@bar.com")

    sent_email |> TestMailer.deliver

    assert_delivered_email sent_email
    refute_delivered_email unsent_email
  end

  test "assert_no_emails_sent" do
    assert_no_emails_sent
  end

  test "assertion helpers format email addresses" do
    user_that_needs_to_be_formatted =
      %Bamboo.Test.User{first_name: "Paul", email: "foo@bar.com"}
    sent_email = new_email(from: user_that_needs_to_be_formatted)

    sent_email |> TestMailer.deliver

    assert_delivered_email sent_email
  end

  defp new_normalized_email(attrs \\ []) do
    [from: "foo@bar.com"]
    |> Keyword.merge(attrs)
    |> new_email
    |> Bamboo.Mailer.normalize_addresses
  end
end

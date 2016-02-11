defmodule Bamboo.LocalAdapterTest do
  use ExUnit.Case
  alias Bamboo.SentEmail
  import Bamboo.Email, only: [new_email: 0, new_email: 1]

  @mailer_config adapter: Bamboo.LocalAdapter

  Application.put_env(:bamboo, __MODULE__.TestMailer, @mailer_config)

  defmodule TestMailer do
    use Bamboo.Mailer, otp_app: :bamboo
  end

  setup do
    SentEmail.reset
    :ok
  end

  test "sent emails has emails that were delivered synchronously" do
    email = new_normalized_email(subject: "This is my email")

    email |> TestMailer.deliver

    assert SentEmail.all == [email]
  end

  test "deliver_later puts email in the mailbox immediately" do
    email = new_normalized_email(subject: "This is my email")

    email |> TestMailer.deliver_later

    assert SentEmail.all == [email]
  end

  test "deliver_later returns a task that can be awaited upon" do
    email = new_normalized_email(subject: "This is my email")

    task = email |> TestMailer.deliver_later

    Task.await(task)
    assert SentEmail.all == [email]
  end

  defp new_normalized_email(attrs) do
    attrs = Keyword.merge([from: "foo@bar.com", to: "foo@bar.com"], attrs)
    new_email(attrs) |> Bamboo.Mailer.normalize_addresses
  end
end

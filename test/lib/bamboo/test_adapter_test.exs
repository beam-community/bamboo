defmodule Bamboo.TestAdapterTest do
  use ExUnit.Case
  use Bamboo.Test
  import Bamboo.Email, only: [new_email: 0, new_email: 1]
  alias Bamboo.TestAdapter

  @config %{}

  Application.put_env(
    :bamboo,
    __MODULE__.TestMailer,
    adapter: Bamboo.TestAdapter
  )

  defmodule TestMailer do
    use Bamboo.Mailer, otp_app: :bamboo
  end

  test "handle_config makes sure that the ImmediateDeliveryStrategy is used" do
    new_config = TestAdapter.handle_config(%{})
    assert new_config.deliver_later_strategy == Bamboo.ImmediateDeliveryStrategy

    new_config = TestAdapter.handle_config(%{deliver_later_strategy: nil})
    assert new_config.deliver_later_strategy == Bamboo.ImmediateDeliveryStrategy

    assert_raise ArgumentError, ~r/deliver_later_strategy/, fn ->
      TestAdapter.handle_config(%{deliver_later_strategy: FooStrategy})
    end
  end

  test "deliver/2 sends a message to the process" do
    email = new_email()

    email |> TestAdapter.deliver_now(@config)

    assert_received {:delivered_email, ^email}
  end

  test "helpers for testing whole emails" do
    sent_email = new_email(from: "foo@bar.com", to: ["foo@bar.com"])
    unsent_email = new_email(from: "foo@bar.com")

    sent_email |> TestMailer.deliver_now

    assert_delivered_email sent_email
    refute_delivered_email unsent_email
  end

  test "helpers for testing against parts of an email" do
    recipient = {nil, "foo@bar.com"}
    sent_email = new_email(from: "foo@bar.com", to: [recipient])

    sent_email |> TestMailer.deliver_now

    refute_delivered_email(from: "someoneelse@bar.com")
    assert_delivered_email(from: "foo@bar.com", to: "foo@bar.com")
  end

  test "assert_no_emails_sent" do
    assert_no_emails_sent
  end

  test "assertion helpers format email addresses" do
    user_that_needs_to_be_formatted =
      %Bamboo.Test.User{first_name: "Paul", email: "foo@bar.com"}
    sent_email =
      new_email(from: user_that_needs_to_be_formatted, to: "foo@bar.com")

    sent_email |> TestMailer.deliver_now

    assert_delivered_email sent_email
  end
end

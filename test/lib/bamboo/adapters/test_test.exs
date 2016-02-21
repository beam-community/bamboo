defmodule Bamboo.Adapters.TestTest do
  use ExUnit.Case
  use Bamboo.Test
  import Bamboo.Email, only: [new_email: 0, new_email: 1]
  alias Bamboo.Adapters.Test

  @config %{}

  Application.put_env(
    :bamboo,
    __MODULE__.TestMailer,
    adapter: Bamboo.Adapters.Test
  )

  defmodule TestMailer do
    use Bamboo.Mailer, otp_app: :bamboo
  end

  test "handle_config makes sure that the ImmediateDelivery strategy is used" do
    new_config = Test.handle_config(%{})
    assert new_config.deliver_later_strategy == Bamboo.Strategies.ImmediateDelivery

    new_config = Test.handle_config(%{deliver_later_strategy: nil})
    assert new_config.deliver_later_strategy == Bamboo.Strategies.ImmediateDelivery

    assert_raise ArgumentError, ~r/deliver_later_strategy/, fn ->
      Test.handle_config(%{deliver_later_strategy: FooStrategy})
    end
  end

  test "deliver/2 sends a message to the process" do
    email = new_email()

    email |> Test.deliver(@config)

    assert_received {:delivered_email, ^email}
  end

  test "helpers for testing whole emails" do
    sent_email = new_email(from: "foo@bar.com", to: ["foo@bar.com"])
    unsent_email = new_email(from: "foo@bar.com")

    sent_email |> TestMailer.deliver

    assert_delivered_email sent_email
    refute_delivered_email unsent_email
  end

  test "helpers for testing against parts of an email" do
    recipient = {nil, "foo@bar.com"}
    sent_email = new_email(from: "foo@bar.com", to: [recipient])

    sent_email |> TestMailer.deliver

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

    sent_email |> TestMailer.deliver

    assert_delivered_email sent_email
  end
end

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

  test "deliver sends a message to the process" do
    email = new_email()

    email |> TestAdapter.deliver(@config)

    email = TestAdapter.clean_assigns(email)

    assert_received {:delivered_email, ^email}
  end

  test "helpers for testing whole emails" do
    sent_email = new_email(from: "foo@bar.com", to: ["foo@bar.com"])
    unsent_email = new_email(from: "foo@bar.com")

    sent_email |> TestMailer.deliver_now

    assert_delivered_email sent_email
    refute_delivered_email unsent_email

    sent_email |> TestMailer.deliver_now
    assert_raise ExUnit.AssertionError, fn ->
      assert_delivered_email %{sent_email | to: "oops"}
    end

    sent_email |> TestMailer.deliver_now
    assert_email_delivered_with(from: {nil, "foo@bar.com"})

    sent_email |> TestMailer.deliver_now
    assert_raise ExUnit.AssertionError, fn ->
      assert_email_delivered_with(from: "oops")
    end
  end

  test "assert_delivered_email with no delivered emails" do
    sent_email = new_email(from: "foo@bar.com", to: ["foo@bar.com"])

    try do
      assert_delivered_email %{sent_email | to: "oops"}
    rescue
      error in [ExUnit.AssertionError] ->
        assert error.message =~ "0 emails delivered"
    else
      _ -> flunk "assert_delivered_email should failed"
    end
  end

  test "assert_no_emails_delivered raises helpful error message" do
    assert_raise RuntimeError, ~r/has been renamed/, fn ->
      assert_no_emails_sent()
    end
  end

  test "assert_delivered_email shows non-matching delivered emails" do
    sent_email = new_email(from: "foo@bar.com", to: ["foo@bar.com"])

    sent_email |> TestMailer.deliver_now()

    try do
      assert_delivered_email %{sent_email | to: "oops"}
    rescue
      error in [ExUnit.AssertionError] ->
        assert error.message =~ "no matching emails"
        assert error.message =~ sent_email.from
    else
      _ -> flunk "assert_delivered_email should failed"
    end
  end

  test "assert_delivered_email filters message that are not emails" do
    sent_email = new_email(from: "foo@bar.com", to: ["foo@bar.com"])

    TestMailer.deliver_now(sent_email)

    send self(), :not_an_email

    try do
      assert_delivered_email %{sent_email | to: "oops"}
    rescue
      error in [ExUnit.AssertionError] ->
        assert error.message =~ "no matching emails"
        refute error.message =~ ":not_an_email"
    else
      _ -> flunk "assert_delivered_email should failed"
    end
  end

  test "assert_email_delivered_with with no delivered emails" do
    try do
      assert_email_delivered_with from: {nil, "foo@bar.com"}
    rescue
      error in [ExUnit.AssertionError] ->
        assert error.message =~ "0 emails delivered"
    else
      _ -> flunk "assert_delivered_email should have failed"
    end
  end

  test "assert_email_delivered_with shows non-matching delivered email" do
    sent_email = new_email(from: "foo@bar.com", to: ["foo@bar.com"])

    sent_email |> TestMailer.deliver_now

    try do
      assert_email_delivered_with to: "oops"
    rescue
      error in [ExUnit.AssertionError] ->
        assert error.message =~ "do not match"
        assert error.message =~ sent_email.from
    else
      _ -> flunk "assert_delivered_email should have failed"
    end
  end

  test "assert_email_delivered_with allows regex matching" do
    new_email(to: {nil, "foo@bar.com"}, from: {nil, "foo@bar.com"}, text_body: "I really like coffee")
      |> TestMailer.deliver_now

    assert_email_delivered_with text_body: ~r/like/
  end

  test "ensure assert_email_delivered_with regex matching doesn't provide a false positive" do
    new_email(to: {nil, "foo@bar.com"}, from: {nil, "foo@bar.com"}, text_body: "I really like coffee")
      |> TestMailer.deliver_now

    try do
      assert_email_delivered_with text_body: ~r/tea/
    rescue
      error in [ExUnit.AssertionError] ->
        assert error.message =~ "do not match"
    else
      _ -> flunk "assert_email_delivered_with should have failed"
    end
  end

  test "assert_no_emails_delivered shows the delivered email" do
    sent_email = new_email(from: "foo@bar.com", to: ["foo@bar.com"])

    TestMailer.deliver_now(sent_email)

    try do
      assert_no_emails_delivered()
    rescue
      error in [ExUnit.AssertionError] ->
        assert error.message =~ "Unexpectedly delivered an email"
        assert error.message =~ sent_email.from
    else
      _ -> flunk "assert_no_emails_delivered should failed"
    end
  end

  test "refute_delivered_email shows the delivered email" do
    sent_email = new_email(from: "foo@bar.com", to: ["foo@bar.com"])

    TestMailer.deliver_now(sent_email)

    try do
      refute_delivered_email sent_email
    rescue
      error in [ExUnit.AssertionError] ->
        assert error.message =~ "Unexpectedly delivered a matching email"
        assert error.message =~ sent_email.from
    else
      _ -> flunk "refute_delivered_email should failed"
    end
  end

  test "assert_no_emails_delivered" do
    assert_no_emails_delivered()

    sent_email = new_email(from: "foo@bar.com", to: "whoever")
    sent_email |> TestMailer.deliver_now

    assert_raise ExUnit.AssertionError, fn ->
      assert_no_emails_delivered()
    end
  end

  test "assertion helpers format email addresses" do
    user_that_needs_to_be_formatted =
      %Bamboo.Test.User{first_name: "Paul", email: "foo@bar.com"}
    sent_email =
      new_email(from: user_that_needs_to_be_formatted, to: "foo@bar.com")

    sent_email |> TestMailer.deliver_now

    assert_delivered_email sent_email
  end

  test "delivered emails have normalized assigns" do
    email = new_email(from: "foo@bar.com", to: "bar@baz.com", assigns: :anything)

    email |> TestMailer.deliver_now

    assert_delivered_email %{email | assigns: :assigns_removed_for_testing}
  end
end

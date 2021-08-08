defmodule Bamboo.TestAdapterTest do
  use ExUnit.Case
  use Bamboo.Test
  import Bamboo.Email, only: [new_email: 0, new_email: 1]
  alias Bamboo.TestAdapter

  Application.put_env(
    :bamboo,
    __MODULE__.TestMailer,
    adapter: Bamboo.TestAdapter
  )

  defmodule TestMailer do
    use Bamboo.Mailer, otp_app: :bamboo
  end

  test "deliver sends a message to the process" do
    email = new_email()
    config = %{}

    email |> TestAdapter.deliver(config)

    email = TestAdapter.clean_assigns(email)

    assert_received {:delivered_email, ^email}
  end

  describe "forward/2" do
    test "forward emails from another process" do
      {:ok, test_adapter_pid} = Bamboo.TestAdapter.start_link([])

      email = new_email()
      config = %{}

      other_process =
        spawn(fn ->
          receive do
            :continue -> email |> TestAdapter.deliver(config)
          end
        end)

      TestAdapter.forward(other_process, self())
      send(other_process, :continue)

      email = TestAdapter.clean_assigns(email)
      assert_receive {:delivered_email, ^email}

      Process.exit(test_adapter_pid, :kill)
    end
  end

  describe "handle_config/1" do
    test "handle_config makes sure that the ImmediateDeliveryStrategy is used" do
      new_config = TestAdapter.handle_config(%{})
      assert new_config.deliver_later_strategy == Bamboo.ImmediateDeliveryStrategy

      new_config = TestAdapter.handle_config(%{deliver_later_strategy: nil})
      assert new_config.deliver_later_strategy == Bamboo.ImmediateDeliveryStrategy

      assert_raise ArgumentError, ~r/deliver_later_strategy/, fn ->
        TestAdapter.handle_config(%{deliver_later_strategy: FooStrategy})
      end
    end
  end

  describe "assert_delivered_email/1" do
    test "succeeds when email is sent" do
      sent_email = new_email(from: "foo@bar.com", to: ["foo@bar.com"])

      sent_email |> TestMailer.deliver_now()

      assert_delivered_email(sent_email)
    end

    test "flunks test when email does not match" do
      sent_email = new_email(from: "foo@bar.com", to: ["foo@bar.com"])

      sent_email |> TestMailer.deliver_now()

      assert_raise ExUnit.AssertionError, ~r/no matching emails/, fn ->
        assert_delivered_email(%{sent_email | to: "oops"})
      end
    end

    test "flunks test when no emails are delivered" do
      sent_email = new_email(from: "foo@bar.com", to: ["foo@bar.com"])

      assert_raise ExUnit.AssertionError, ~r/0 emails delivered/, fn ->
        assert_delivered_email(%{sent_email | to: "oops"})
      end
    end

    test "shows non-matching delivered emails" do
      sent_email = new_email(from: "foo@bar.com", to: ["foo@bar.com"])

      sent_email |> TestMailer.deliver_now()

      assert_raise ExUnit.AssertionError, ~r/#{sent_email.from}/, fn ->
        assert_delivered_email(%{sent_email | to: "oops"})
      end
    end

    test "filters message that are not emails" do
      sent_email = new_email(from: "foo@bar.com", to: ["foo@bar.com"])

      TestMailer.deliver_now(sent_email)

      send(self(), :not_an_email)

      try do
        assert_delivered_email(%{sent_email | to: "oops"})
      rescue
        error in [ExUnit.AssertionError] ->
          assert error.message =~ "no matching emails"
          refute error.message =~ ":not_an_email"
      else
        _ -> flunk("assert_delivered_email should failed")
      end
    end

    test "formats email addresses" do
      user_that_needs_to_be_formatted = %Bamboo.Test.User{
        first_name: "Paul",
        email: "foo@bar.com"
      }

      sent_email = new_email(from: user_that_needs_to_be_formatted, to: "foo@bar.com")

      sent_email |> TestMailer.deliver_now()

      assert_delivered_email(sent_email)
    end

    test "delivered emails have normalized assigns" do
      email = new_email(from: "foo@bar.com", to: "bar@baz.com", assigns: :anything)

      email |> TestMailer.deliver_now()

      assert_delivered_email(%{email | assigns: :assigns_removed_for_testing})
    end

    test "accepts timeout" do
      email = new_email(from: "foo@bar.com", to: "bar@baz.com")

      email |> TestMailer.deliver_now()

      assert_delivered_email(email, timeout: 1)
    end
  end

  describe "refute_delivered_email/1" do
    test "succeeds when email is not sent" do
      unsent_email = new_email(from: "foo@bar.com")

      refute_delivered_email(unsent_email)
    end

    test "flunks when a test is sent" do
      sent_email = new_email(from: "foo@bar.com", to: ["foo@bar.com"])

      sent_email |> TestMailer.deliver_now()

      assert_raise ExUnit.AssertionError, ~r/Unexpectedly delivered a matching email/, fn ->
        refute_delivered_email(sent_email)
      end
    end

    test "shows the delivered email when flunking" do
      sent_email = new_email(from: "foo@bar.com", to: ["foo@bar.com"])

      TestMailer.deliver_now(sent_email)

      assert_raise ExUnit.AssertionError, ~r/#{sent_email.from}/, fn ->
        refute_delivered_email(sent_email)
      end
    end

    test "accepts a timeout configuration" do
      unsent_email = new_email(from: "foo@bar.com")

      refute_delivered_email(unsent_email, timeout: 1)
    end
  end

  describe "assert_email_delivered_with/1" do
    test "succeeds when attributes match delivered email" do
      sent_email = new_email(from: "foo@bar.com", to: ["foo@bar.com"])

      sent_email |> TestMailer.deliver_now()

      assert_email_delivered_with(from: "foo@bar.com")
    end

    test "normalizes the email on assertion" do
      sent_email = new_email(from: "foo@bar.com", to: ["foo@bar.com"])

      sent_email |> TestMailer.deliver_now()

      assert_email_delivered_with(from: {nil, "foo@bar.com"})
    end

    test "flunks test if email attributes differ" do
      sent_email = new_email(from: "foo@bar.com", to: ["foo@bar.com"])

      sent_email |> TestMailer.deliver_now()

      assert_raise ExUnit.AssertionError, ~r/parameters given do not match/, fn ->
        assert_email_delivered_with(from: "oops")
      end
    end

    test "flunks test when no emails are delivered" do
      assert_raise ExUnit.AssertionError, ~r/0 emails delivered/, fn ->
        assert_email_delivered_with(from: {nil, "foo@bar.com"})
      end
    end

    test "shows non-matching delivered email when failing test" do
      sent_email = new_email(from: "foo@bar.com", to: ["foo@bar.com"])

      sent_email |> TestMailer.deliver_now()

      try do
        assert_email_delivered_with(to: "oops")
      rescue
        error in [ExUnit.AssertionError] ->
          assert error.message =~ "do not match"
          assert error.message =~ sent_email.from
      else
        _ -> flunk("assert_delivered_email should have failed")
      end
    end

    test "allows regex matching" do
      new_email(
        to: {nil, "foo@bar.com"},
        from: {nil, "foo@bar.com"},
        text_body: "I really like coffee"
      )
      |> TestMailer.deliver_now()

      assert_email_delivered_with(text_body: ~r/like/)
    end

    test "regex matching doesn't provide a false positive" do
      new_email(
        to: {nil, "foo@bar.com"},
        from: {nil, "foo@bar.com"},
        text_body: "I really like coffee"
      )
      |> TestMailer.deliver_now()

      assert_raise ExUnit.AssertionError, ~r/do not match/, fn ->
        assert_email_delivered_with(text_body: ~r/tea/)
      end
    end

    test "accepts timeout" do
      email = new_email(from: "foo@bar.com", to: "bar@baz.com")

      email |> TestMailer.deliver_now()

      assert_email_delivered_with([from: "foo@bar.com"], timeout: 1)
    end
  end

  describe "refute_email_delivered_with/1" do
    test "succeeds when email does not match" do
      mail =
        new_email(
          to: [nil: "foo@bar.com"],
          from: {nil, "baz@bar.com"},
          subject: "coffee"
        )

      TestMailer.deliver_now(mail)
      refute_email_delivered_with(subject: ~r/tea/)
      refute_email_delivered_with(to: [nil: "something@else.com"])
    end

    test "flunks test when email matches" do
      mail =
        new_email(
          to: [nil: "foo@bar.com"],
          from: {nil, "foo@bar.com"},
          subject: "vodka",
          text_body: "I really like coffee"
        )

      TestMailer.deliver_now(mail)

      assert_raise ExUnit.AssertionError, fn ->
        refute_email_delivered_with(to: mail.to)
      end

      TestMailer.deliver_now(mail)

      assert_raise ExUnit.AssertionError, fn ->
        refute_email_delivered_with(subject: mail.subject)
      end

      TestMailer.deliver_now(mail)

      assert_raise ExUnit.AssertionError, fn ->
        refute_email_delivered_with(text_body: ~r/coffee/)
      end
    end

    test "accepts a timeout configuration" do
      mail = new_email(to: [nil: "foo@bar.com"], from: {nil, "baz@bar.com"})

      TestMailer.deliver_now(mail)

      refute_email_delivered_with([to: [nil: "something@else.com"]], timeout: 1)
    end
  end

  describe "assert_no_emails_sent/0" do
    test "raises error message about renaming" do
      assert_raise RuntimeError, ~r/has been renamed/, fn ->
        assert_no_emails_sent()
      end
    end
  end

  describe "assert_no_emails_delivered/0" do
    test "shows the delivered email when flunking test" do
      sent_email = new_email(from: "foo@bar.com", to: ["foo@bar.com"])

      TestMailer.deliver_now(sent_email)

      try do
        assert_no_emails_delivered()
      rescue
        error in [ExUnit.AssertionError] ->
          assert error.message =~ "Unexpectedly delivered an email"
          assert error.message =~ sent_email.from
      else
        _ -> flunk("assert_no_emails_delivered should failed")
      end
    end

    test "flunks test if emails were delivered" do
      assert_no_emails_delivered()

      sent_email = new_email(from: "foo@bar.com", to: "whoever")
      sent_email |> TestMailer.deliver_now()

      assert_raise ExUnit.AssertionError, fn ->
        assert_no_emails_delivered()
      end
    end

    test "accepts a timeout configuration" do
      sent_email = new_email(from: "foo@bar.com", to: "whoever")
      sent_email |> TestMailer.deliver_now()

      assert_raise ExUnit.AssertionError, fn ->
        assert_no_emails_delivered(timeout: 1)
      end
    end
  end

  describe "assert_delivered_email_matches/1" do
    test "flunks test with no delivered emails" do
      assert_raise ExUnit.AssertionError, fn ->
        assert_delivered_email_matches(%{to: ["foo@bar.com"]})
      end
    end

    test "allows binding of variables for further testing" do
      sent_email = new_email(from: "foo@bar.com", to: ["foo@bar.com"])
      TestMailer.deliver_now(sent_email)

      assert_delivered_email_matches(%{to: [{nil, email}]})
      assert email == "foo@bar.com"
    end

    test "accepts timeout" do
      sent_email = new_email(from: "foo@bar.com", to: ["foo@bar.com"])

      TestMailer.deliver_now(sent_email)

      assert_delivered_email_matches(%{to: [{nil, "foo@bar.com"}]}, timeout: 1)
    end
  end
end

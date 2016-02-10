defmodule Bamboo.Test do
  @moduledoc """
  Helpers for testing email delivery

  Use these helpers with Bamboo.TestAdapter to test email delivery. Typically
  you'll want to **unit test emails and then in integration tests use
  helpers from this module** to test whether that email was delivered.

  ## Testing email delivery

      defmodule MyApp.Email do
        use Bamboo.Email

        def welcome_email(user) do
          new_email(
            from: "me@app.com",
            to: user,
            subject: "Welcome!",
            text_body: "Welcome to the app",
            html_body: "<strong>Welcome to the app</strong>"
          )
        end
      end

      defmodule MyApp.EmailDeliveryTest do
        use ExUnit.Case

        use Bamboo.Test
        alias MyApp.Emails

        test "sends welcome email" do
          user = %User{...}
          email = Emails.welcome_email(user)

          email |> MyApp.Mailer.deliver

          # Also works with MyApp.Mailer.deliver_async
          assert_delivered_email Emails.welcome_email(user)
        end
      end

  ## Unit testing example

  You don't need any special functions to unit test emails.

      defmodule MyApp.EmailsTest do
        use ExUnit.Case

        alias MyApp.Emails

        test "welcome email" do
          user = %User{name: "John", email: "person@example.com"}
          email = Emails.welcome_email(user)

          assert email.to == user
          assert email.subject == "This is your welcome email"
          assert email.html_body =~ "Welcome to the app"
        end
      end
  """

  @doc """
  Imports Bamboo.Test and Bamboo.Formatter.format_email_address/2
  """
  defmacro __using__(_opts) do
    quote do
      import Bamboo.Formatter, only: [format_email_address: 2]
      import Bamboo.Test
    end
  end

  @doc """
  Checks whether an email was delivered.

  Must be used with the Bamboo.TestAdapter or this will never pass.

  ## Examples

      email = Bamboo.Email.new_email(subject: "something")
      email |> MyApp.Mailer.deliver
      assert_delivered_email(email) # Will pass

      unsent_email = Bamboo.Email.new_email(subject: "something else")
      assert_delivered_email(unsent_email) # Will fail
  """
  def assert_delivered_email(email) do
    import ExUnit.Assertions
    email = Bamboo.Mailer.normalize_addresses(email)
    assert_received {:delivered_email, ^email}
  end

  @doc """
  Checks that no emails were sent.
  """
  def assert_no_emails_sent do
    import ExUnit.Assertions
    refute_received {:delivered_email, _}
  end

  @doc """
  Ensures a particular email was not sent
  """
  def refute_delivered_email(email) do
    import ExUnit.Assertions
    email = Bamboo.Mailer.normalize_addresses(email)
    refute_received {:delivered_email, ^email}
  end
end

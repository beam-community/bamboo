defmodule Bamboo.Test do
  @moduledoc """
  Helpers for testing email delivery

  Use these helpers with Bamboo.TestAdapter to test email delivery. Typically
  you'll want to **unit test emails first**. Then in integration tests use
  helpers from this module to test whether that email was delivered.

  ## In your config

      # Typically in config/test.exs
      config :my_app, MyApp.Mailer,
        adapter: Bamboo.TestAdapter

  ## Unit test

  You don't need any special functions to unit test emails.

      defmodule MyApp.EmailsTest do
        use ExUnit.Case

        test "welcome email" do
          user = %User{name: "John", email: "person@example.com"}

          email = MyApp.Email.welcome_email(user)

          assert email.to == user
          assert email.subject == "This is your welcome email"
          assert email.html_body =~ "Welcome to the app"
        end
      end

  ## Integration test

      defmodule MyApp.Email do
        import Bamboo.Email

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

        test "sends welcome email" do
          user = %User{...}
          email = MyApp.Email.welcome_email(user)

          email |> MyApp.Mailer.deliver_now

          # Works with deliver_now and deliver_later
          assert_delivered_email MyAppEmail.welcome_email(user)
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

  Must be used with the Bamboo.TestAdapter or this will never pass. If a
  Bamboo.Email struct is passed in, it will check that all fields are matching.

  You can also pass a keyword list and it will check just the fields you pass in.

  ## Examples

      email = Bamboo.Email.new_email(subject: "something")
      email |> MyApp.Mailer.deliver
      assert_delivered_email(email) # Will pass

      unsent_email = Bamboo.Email.new_email(subject: "something else")
      assert_delivered_email(unsent_email) # Will fail
  """
  def assert_delivered_email(%Bamboo.Email{} = email) do
    import ExUnit.Assertions
    email = Bamboo.Mailer.normalize_addresses(email)
    assert_received {:delivered_email, ^email}
  end
  def assert_delivered_email(email_options) when is_list(email_options) do
    import ExUnit.Assertions
    email = Bamboo.Email.new_email(email_options)
      |> Bamboo.Mailer.normalize_addresses
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

  Same as assert_delivered_email, except it checks that an email was not sent.
  """
  def refute_delivered_email(%Bamboo.Email{} = email) do
    import ExUnit.Assertions
    email = Bamboo.Mailer.normalize_addresses(email)
    refute_received {:delivered_email, ^email}
  end
  def refute_delivered_email(email_options) when is_list(email_options) do
    import ExUnit.Assertions
    email = Bamboo.Email.new_email(email_options)
      |> Bamboo.Mailer.normalize_addresses
    refute_received {:delivered_email, ^email}
  end
end

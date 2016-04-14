defmodule Bamboo.Test do
  @timeout 100

  import ExUnit.Assertions

  @moduledoc """
  Helpers for testing email delivery

  Use these helpers with Bamboo.TestAdapter to test email delivery. Typically
  you'll want to **unit test emails first**. Then in integration tests use
  helpers from this module to test whether that email was delivered.

  ## Note on sending from other processes

  If you are sending emails from another process (for example, from inside a
  Task or GenServer) you may need to use the `process_name` option when using
  `Bamboo.Test`. See the docs `__using__/1` for an example.

  For most scenarios you will not need the `process_name` option.

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

  `Bamboo.Test` and the `Bamboo.TestAdapter` work by sending a message to the
  current process when an email is delivered. The process mailbox is then
  checked when using the assertion helpers like `assert_delivered_email/1`.

  Sometimes emails don't show up when asserting because you may deliver an email
  from a _different_ process than the test process. When that happens, set the
  `process_name`. This will name the test process using `Process.register/2`
  and set `Bamboo.TestAdapter` to always send to that process. This means
  that you cannot use `process_name` with async tests.

  ## Try to use this version first

      use Bamboo.Test

  ## And if you are delivering from another process, set `process_name`

      # Note: the process name can be whatever you want.
      use Bamboo.Test, process_name: :name_of_my_test


  Common scenarios for delivering mail from a different process are when you
  send from inside of a Task, GenServer, or are running acceptance tests with a
  headless browser like phantomjs.
  """
  defmacro __using__(process_name: process_name) do
    quote do
      setup tags do
        if tags[:async] do
          raise """
          passing process_name to Bamboo.Test cannot be done for async tests.

          There are a few options, the 1st is the easiest:

            1) Set your test to [async: false].
            2) If you are delivering emails from another process (for example,
               delivering from within Task.async or Process.spawn), try using
               Mailer.deliver_later. If you use Mailer.deliver_later without
               spawning another process you can use Bamboo.Test with [async:
               true] and without the process_name option.
            3) If you are doing an acceptance test that requires the process_name
               option, try using a controller test instead. Then see if the test
               works without the process_name option.
          """
        else
          Application.put_env(:bamboo, :test_process_name, unquote(process_name))
          Process.register(self, unquote(process_name))
        end

        :ok
      end

      import Bamboo.Formatter, only: [format_email_address: 2]
      import Bamboo.Test
    end
  end

  defmacro __using__(_opts) do
    quote do
      setup tags do
        Application.delete_env(:bamboo, :test_process_name)

        :ok
      end

      import Bamboo.Formatter, only: [format_email_address: 2]
      import Bamboo.Test
    end
  end

  @doc """
  Checks whether an email was delivered.

  Must be used with the `Bamboo.TestAdapter` or this will never pass. In case you
  are delivering from another process, the assertion waits up to 100ms before
  failing. Typically if an email is successfully delivered the assertion will
  pass instantly, so test suites will remain fast.

  ## Examples

      email = Bamboo.Email.new_email(subject: "something")
      email |> MyApp.Mailer.deliver
      assert_delivered_email(email) # Will pass

      unsent_email = Bamboo.Email.new_email(subject: "something else")
      assert_delivered_email(unsent_email) # Will fail
  """
  def assert_delivered_email(%Bamboo.Email{} = email) do
    email = Bamboo.Mailer.normalize_addresses(email)
    do_assert_delivered_email(email)
  end

  defp do_assert_delivered_email(email) do
    receive do
      {:delivered_email, ^email} -> true
    after
      @timeout -> flunk_with_email_list(email)
    end
  end

  defp flunk_with_email_list(email) do
    if Enum.empty?(delivered_emails) do
      flunk """
      There were 0 emails delivered to this process.

      If you expected an email to be sent, try these ideas:

        1) Make sure you call deliver_now/1 or deliver_later/1 to deliver the email
        2) Make sure you are using the Bamboo.TestAdapter
        3) Use the process_name feature of Bamboo.Test. This will allow Bamboo.Test
           to work across processes: use Bamboo.Test, process_name: :my_test_name
        4) If you are writing an acceptance test through a headless browser, use
           the process_name feature described in option 3.
      """
    else
      flunk """
      There were no matching emails.

      No emails matched:

        #{inspect email}

      Delivered emails:

      #{delivered_emails_as_list}
      """
    end
  end

  defp delivered_emails do
    {:messages, messages} = Process.info(self, :messages)

    for {:delivered_email, _} = email_message <- messages do
      email_message
    end
  end

  defp delivered_emails_as_list do
    delivered_emails |> add_asterisk |> Enum.join("\n")
  end

  defp add_asterisk(emails) do
    Enum.map(emails, &" * #{inspect &1}")
  end

  @doc """
  Checks that no emails were sent.

  If used with the process_name feature of `Bamboo.Test`, you must also configure
  a timeout in your test config.

      # Set this in your config, typically in config/test.exs
      config :bamboo, :refute_timeout, 10

  The value you set is up to you. Lower values will result in faster tests,
  but may incorrectly pass if an email is delivered *after* the timeout. Often
  times 1ms is enough.
  """
  def assert_no_emails_delivered do
    receive do
      {:delivered_email, email} -> flunk_with_unexpected_email(email)
    after
      refute_timeout -> true
    end
  end

  @doc false
  def assert_no_emails_sent do
    raise "assert_no_emails_sent/0 has been renamed to assert_no_emails_delivered/0"
  end

  defp flunk_with_unexpected_email(email) do
    flunk """
    Unexpectedly delivered an email when expected none to be delivered.

    Delivered email:

      #{inspect email}
    """
  end

  @doc """
  Ensures a particular email was not sent

  Same as `assert_delivered_email/0`, except it checks that a particular email
  was not sent.

  If used with the process_name feature of `Bamboo.Test`, you must also configure
  a timeout in your test config.

      # Set this in your config, typically in config/test.exs
      config :bamboo, :refute_timeout, 10

  The value you set is up to you. Lower values will result in faster tests,
  but may incorrectly pass if an email is delivered *after* the timeout. Often
  times 1ms is enough.
  """
  def refute_delivered_email(%Bamboo.Email{} = email) do
    email = Bamboo.Mailer.normalize_addresses(email)

    receive do
      {:delivered_email, ^email} -> flunk_with_unexpected_matching_email(email)
    after
      refute_timeout -> true
    end
  end

  defp flunk_with_unexpected_matching_email(email) do
    flunk """
    Unexpectedly delivered a matching email.

    Matched email that was delivered:

      #{inspect email}
    """
  end

  defp refute_timeout do
    if using_process_name? do
      Application.get_env(:bamboo, :refute_timeout) || raise """
      When using process_name with Bamboo.Test, you must set a timeout. This
      is because an email can be delivered after the assertion is called.

          # Set this in your config, typically in config/test.exs
          config :bamboo, :refute_timeout, 10

      The value you set is up to you. Lower values will result in faster tests,
      but may incorrectly pass if an email is delivered *after* the timeout.
      """
    else
      0
    end
  end

  defp using_process_name? do
    !!Application.get_env(:bamboo, :test_process_name)
  end
end

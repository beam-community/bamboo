defmodule Bamboo.Test do
  import ExUnit.Assertions

  @moduledoc """
  Helpers for testing email delivery.

  Use these helpers with `Bamboo.TestAdapter` to test email delivery. Typically
  you'll want to **unit test emails first**. Then, in integration tests, use
  helpers from this module to test whether that email was delivered.

  ## Note on sending from other processes

  If you are sending emails from another process (for example, from inside a
  Task or GenServer) you may need to use shared mode when using
  `Bamboo.Test`. See the docs `__using__/1` for an example.

  For most scenarios you will not need shared mode.

  ## In your config

      # Typically in config/test.exs
      config :my_app, MyApp.Mailer,
        adapter: Bamboo.TestAdapter

  ## Unit test

  You don't need any special functions to unit test emails.

      defmodule MyApp.EmailTest do
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
          assert_delivered_email email
        end
      end
  """

  @doc """
  Imports `Bamboo.Test` and `Bamboo.Formatter.format_email_address/2`

  `Bamboo.Test` and the `Bamboo.TestAdapter` work by sending a message to the
  current process when an email is delivered. The process mailbox is then
  checked when using the assertion helpers like `assert_delivered_email/1`.

  Sometimes emails don't show up when asserting because you may deliver an email
  from a _different_ process than the test process. When that happens, turn on
  shared mode. This will tell `Bamboo.TestAdapter` to always send to the test process.
  This means that you cannot use shared mode with async tests.

  ## Try to use this version first

      use Bamboo.Test

  ## And if you are delivering from another process, set `shared: true`

      use Bamboo.Test, shared: true

  Common scenarios for delivering mail from a different process are when you
  send from inside of a Task, GenServer, or are running acceptance tests with a
  headless browser like phantomjs.
  """
  defmacro __using__(shared: true) do
    quote do
      setup tags do
        if tags[:async] do
          raise """
          you cannot use Bamboo.Test shared mode with async tests.

          There are a few options, the 1st is the easiest:

            1) Set your test to [async: false].
            2) If you are delivering emails from another process (for example,
               delivering from within Task.async or Process.spawn), try using
               Mailer.deliver_later. If you use Mailer.deliver_later without
               spawning another process you can use Bamboo.Test with [async:
               true] and without the shared mode.
            3) If you are writing an acceptance test that requires shared mode,
               try using a controller test instead. Then see if the test works
               without shared mode.
          """
        else
          Application.put_env(:bamboo, :shared_test_process, self())
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
        Application.delete_env(:bamboo, :shared_test_process)

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
  defmacro assert_delivered_email(email) do
    quote do
      import ExUnit.Assertions
      email = Bamboo.Test.normalize_for_testing(unquote(email))
      assert_receive({:delivered_email, ^email}, 100, Bamboo.Test.flunk_with_email_list(email))
    end
  end

  @doc """
  Checks whether an email was delivered matching the given pattern.

  Must be used with the `Bamboo.TestAdapter` or this will never pass. This
  allows the user to use their configured `assert_receive_timeout` for ExUnit,
  and also to match any variables in their given pattern for use in further
  assertions.

  ## Examples

      %{email: user_email, name: user_name} = user
      MyApp.deliver_welcome_email(user)
      assert_delivered_email_matches(%{to: [{_, ^user_email}], text_body: text_body})
      assert text_body =~ "Welcome to MyApp, #\{user_name}"
      assert text_body =~ "You can sign up at https://my_app.com/users/#\{user_name}"
  """
  defmacro assert_delivered_email_matches(email_pattern) do
    quote do
      import ExUnit.Assertions
      ExUnit.Assertions.assert_receive({:delivered_email, unquote(email_pattern)})
    end
  end

  @doc """
  Check whether an email's params are equal to the ones provided.

  Must be used with the `Bamboo.TestAdapter` or this will never pass. In case you
  are delivering from another process, the assertion waits up to 100ms before
  failing. Typically if an email is successfully delivered the assertion will
  pass instantly, so test suites will remain fast.

  ## Examples

      email = Bamboo.Email.new_email(subject: "something")
      email |> MyApp.Mailer.deliver
      assert_email_delivered_with(subject: "something") # Will pass

      unsent_email = Bamboo.Email.new_email(subject: "something else")
      assert_email_delivered_with(subject: "something else") # Will fail

  The function will use the Bamboo Formatter when checking email addresses.

      email = Bamboo.Email.new_email(to: "someone@example.com")
      email |> MyApp.Mailer.deliver
      assert_email_delivered_with(to: "someone@example.com") # Will pass

  You can also pass a regex to match portions of an email.

  ## Example

      email = new_email(text_body: "I love coffee")
      email |> MyApp.Mailer.deliver
      assert_email_delivered_with(text_body: ~r/love/) # Will pass
      assert_email_delivered_with(text_body: ~r/like/) # Will fail
  """
  defmacro assert_email_delivered_with(email_params) do
    quote bind_quoted: [email_params: email_params] do
      import ExUnit.Assertions
      assert_receive({:delivered_email, email}, 100, Bamboo.Test.flunk_no_emails_received())

      received_email_params = email |> Map.from_struct()

      assert Enum.all?(email_params, fn {k, v} -> do_match(received_email_params[k], v, k) end),
             Bamboo.Test.flunk_attributes_do_not_match(email_params, received_email_params)
    end
  end

  @doc """
  Check that no email was sent with the given parameters

  Similarly to `assert_email_delivered_with`, the assertion waits up to 100ms before
  failing. Note that you need to send the email again if you want to make other
  assertions after this, as this will receive the `{:delivered_email, email}` message.

  ## Examples

      Bamboo.Email.new_email(subject: "something") |> MyApp.Mailer.deliver
      refute_email_delivered_with(subject: "something else") # Will pass

      email = Bamboo.Email.new_email(subject: "something") |> MyApp.Mailer.deliver
      refute_email_delivered_with(subject: ~r/some/) # Will fail
  """
  defmacro refute_email_delivered_with(email_params) do
    quote bind_quoted: [email_params: email_params] do
      import ExUnit.Assertions

      received_email_params =
        receive do
          {:delivered_email, email} -> Map.from_struct(email)
        after
          100 -> []
        end

      if is_nil(received_email_params) do
        refute false
      else
        refute Enum.any?(email_params, fn {k, v} -> do_match(received_email_params[k], v, k) end),
               Bamboo.Test.flunk_attributes_match(email_params, received_email_params)
      end
    end
  end

  @doc false
  def do_match(value1, value2 = %Regex{}, _type) do
    Regex.match?(value2, value1)
  end

  @doc false
  def do_match(value1, value2, type) do
    value1 == value2 || value1 == format(value2, type)
  end

  @doc false
  defp format(record, type) do
    Bamboo.Formatter.format_email_address(record, %{type: type})
  end

  @doc false
  def flunk_with_email_list(email) do
    if Enum.empty?(delivered_emails()) do
      flunk_no_emails_received()
    else
      flunk("""
      There were no matching emails.

      No emails matched:

        #{inspect(email)}

      Delivered emails:

      #{delivered_emails_as_list()}
      """)
    end
  end

  @doc false
  def flunk_no_emails_received do
    flunk("""
    There were 0 emails delivered to this process.

    If you expected an email to be sent, try these ideas:

    1) Make sure you call deliver_now/1 or deliver_later/1 to deliver the email
    2) Make sure you are using the Bamboo.TestAdapter
    3) Use shared mode with Bamboo.Test. This will allow Bamboo.Test
    to work across processes: use Bamboo.Test, shared: :true
    4) If you are writing an acceptance test through a headless browser, use
    shared mode as described in option 3.
    """)
  end

  @doc false
  def flunk_attributes_do_not_match(params_given, params_received) do
    """
    The parameters given do not match.

      Parameters given:

        #{inspect(params_given)}

      Email received:

        #{inspect(params_received)}
    """
  end

  @doc false
  def flunk_attributes_match(params_given, params_received) do
    """
    The parameters given match.

      Parameters given:

        #{inspect(params_given)}

      Email received:

        #{inspect(params_received)}
    """
  end

  defp delivered_emails do
    {:messages, messages} = Process.info(self(), :messages)

    for {:delivered_email, _} = email_message <- messages do
      email_message
    end
  end

  defp delivered_emails_as_list do
    delivered_emails() |> add_asterisk |> Enum.join("\n")
  end

  defp add_asterisk(emails) do
    Enum.map(emails, &" * #{inspect(&1)}")
  end

  @doc """
  Checks that no emails were sent.

  If `Bamboo.Test` is used with shared mode, you must also configure a timeout
  in your test config.

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
      refute_timeout() -> true
    end
  end

  @doc false
  def assert_no_emails_sent do
    raise "assert_no_emails_sent/0 has been renamed to assert_no_emails_delivered/0"
  end

  defp flunk_with_unexpected_email(email) do
    flunk("""
    Unexpectedly delivered an email when expected none to be delivered.

    Delivered email:

      #{inspect(email)}
    """)
  end

  @doc """
  Ensures a particular email was not sent

  Same as `assert_delivered_email/0`, except it checks that a particular email
  was not sent.

  If `Bamboo.Test` is used with shared mode, you must also configure a timeout
  in your test config.

      # Set this in your config, typically in config/test.exs
      config :bamboo, :refute_timeout, 10

  The value you set is up to you. Lower values will result in faster tests,
  but may incorrectly pass if an email is delivered *after* the timeout. Often
  times 1ms is enough.
  """
  def refute_delivered_email(%Bamboo.Email{} = email) do
    email = normalize_for_testing(email)

    receive do
      {:delivered_email, ^email} -> flunk_with_unexpected_matching_email(email)
    after
      refute_timeout() -> true
    end
  end

  defp flunk_with_unexpected_matching_email(email) do
    flunk("""
    Unexpectedly delivered a matching email.

    Matched email that was delivered:

      #{inspect(email)}
    """)
  end

  defp refute_timeout do
    if using_shared_mode?() do
      Application.get_env(:bamboo, :refute_timeout) ||
        raise """
        When using shared mode with Bamboo.Test, you must set a timeout. This
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

  defp using_shared_mode? do
    !!Application.get_env(:bamboo, :shared_test_process)
  end

  @doc false
  def normalize_for_testing(email) do
    email
    |> Bamboo.Mailer.normalize_addresses()
    |> Bamboo.TestAdapter.clean_assigns()
  end
end

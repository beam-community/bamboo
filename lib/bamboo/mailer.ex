defmodule Bamboo.Mailer do
  @moduledoc """
  Sets up mailers that make it easy to configure and swap adapters.

  Adds `deliver_now/1` and `deliver_later/1` functions to the mailer module it is used by.

  ## Bamboo ships with the following adapters

  * `Bamboo.MandrillAdapter`
  * `Bamboo.LocalAdapter`
  * `Bamboo.TestAdapter`
  * or create your own with `Bamboo.Adapter`

  ## Example

      # In your config/config.exs file
      config :my_app, MyApp.Mailer,
        adapter: Bamboo.MandrillAdapter,
        api_key: "my_api_key"

      # Somewhere in your application. Maybe lib/my_app/mailer.ex
      defmodule MyApp.Mailer do
        # Adds deliver_now/1 and deliver_later/1
        use Bamboo.Mailer, otp_app: :my_app
      end

      # Set up your emails
      defmodule MyApp.Email do
        import Bamboo.Email

        def welcome_email do
          new_mail(
            to: "foo@example.com",
            from: "me@example.com",
            subject: "Welcome!!!",
            html_body: "<strong>WELCOME</strong>",
            text_body: "WELCOME"
          )
        end
      end

      # In a Phoenix controller or some other module
      defmodule MyApp.Foo do
        alias MyApp.Emails
        alias MyApp.Mailer

        def register_user do
          # Create a user and whatever else is needed
          # Could also have called Mailer.deliver_later
          Email.welcome_email |> Mailer.deliver_now
        end
      end
  """

  @cannot_call_directly_error """
  cannot call Bamboo.Mailer directly. Instead implement your own Mailer module
  with: use Bamboo.Mailer, otp_app: :my_app
  """

  require Logger
  alias Bamboo.Formatter

  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do

      @spec deliver_now(Bamboo.Email.t) :: Bamboo.Email.t
      def deliver_now(email) do
        Bamboo.Mailer.deliver_now(adapter, email, config)
      end

      @spec deliver_later(Bamboo.Email.t) :: Bamboo.Email.t
      def deliver_later(email) do
        Bamboo.Mailer.deliver_later(adapter, email, config)
      end

      def deliver(_email) do
        raise """
        you called deliver/1, but it has been renamed to deliver_now/1 to add clarity.

        Use deliver_now/1 to send right away, or deliver_later/1 to send in the background.
        """
      end

      if Keyword.get(opts, :dynamic_config, false) do
        defp config, do: Bamboo.Mailer.parse_opts(__MODULE__, unquote(opts))
      else
        @config Bamboo.Mailer.parse_opts(__MODULE__, opts)
        defp config, do: @config
      end

      defp adapter, do: config.adapter
    end
  end

  @doc """
  Deliver an email right away

  Call your mailer with `deliver_now/1` to send an email right away. Call
  `deliver_later/1` if you want to send in the background to speed things up.
  """
  def deliver_now(_email) do
    raise @cannot_call_directly_error
  end

  @doc """
  Deliver an email in the background

  Call your mailer with `deliver_later/1` to send an email using the configured
  `deliver_later_strategy`. If no `deliver_later_strategy` is set,
  `Bamboo.TaskSupervisorStrategy` will be used. See
  `Bamboo.DeliverLaterStrategy` to learn how to change how emails are delivered
  with `deliver_later/1`.
  """
  def deliver_later(_email) do
    raise @cannot_call_directly_error
  end

  @doc false
  def deliver_now(adapter, email, config) do
    email = email |> validate_and_normalize

    if email.to == [] && email.cc == [] && email.bcc == [] do
      debug_unsent(email)
    else
      debug_sent(email, adapter)
      adapter.deliver(email, config)
    end
    email
  end

  @doc false
  def deliver_later(adapter, email, config) do
    email = email |> validate_and_normalize

    if email.to == [] && email.cc == [] && email.bcc == [] do
      debug_unsent(email)
    else
      debug_sent(email, adapter)
      config.deliver_later_strategy.deliver_later(adapter, email, config)
    end
    email
  end

  defp debug_sent(email, adapter) do
    Logger.debug """
    Sending email with #{inspect adapter}:

    #{inspect email, limit: :infinity}
    """
  end

  defp debug_unsent(email) do
    Logger.debug """
    Email was not sent because recipients are empty.

    Full email - #{inspect email, limit: :infinity}
    """
  end

  defp validate_and_normalize(email) do
    email |> validate |> normalize_addresses
  end

  defp validate(%{from: nil}) do
    raise Bamboo.EmptyFromAddressError, nil
  end
  defp validate(%{to: nil, cc: nil, bcc: nil} = email) do
    raise Bamboo.NilRecipientsError, email
  end
  defp validate(email), do: email

  @doc """
  Wraps to, cc and bcc addresses in a list and normalizes email addresses.

  Also formats the from address. Email normalization/formatting is done by the
  [Bamboo.Formatter] protocol.
  """
  def normalize_addresses(email) do
    %{email |
      from: format(email.from, :from),
      to: format(List.wrap(email.to), :to),
      cc: format(List.wrap(email.cc), :cc),
      bcc: format(List.wrap(email.bcc), :bcc)
    }
  end

  defp format(record, type) do
    Formatter.format_email_address(record, %{type: type})
  end

  @doc false
  def parse_opts(mailer, opts) do
    otp_app = Keyword.fetch!(opts, :otp_app)
    config = Application.fetch_env!(otp_app, mailer) |> Enum.into(%{})

    config.adapter.handle_config(config)
    |> Map.put_new(:deliver_later_strategy, Bamboo.TaskSupervisorStrategy)
  end
end

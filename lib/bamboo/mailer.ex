defmodule Bamboo.Mailer do
  @moduledoc """
  Sets up mailers that make it easy to configure and swap adapters.

  Adds deliver/1 and deliver_later/1 functions to the mailer module it is used by.
  Bamboo ships with [Bamboo.MandrillAdapter](Bamboo.MandrillAdapter.html),
  [Bamboo.LocalAdapter](Bamboo.LocalAdapter) and
  [Bamboo.TestAdapter](Bamboo.TestAdapter.html).

  ## Example

      # In your config/config.exs file
      # Other adapters that come with Bamboo are
      # Bamboo.LocalAdapter and Bamboo.TestAdapter
      config :my_app, MyApp.Mailer,
        adapter: Bamboo.MandrillAdapter,
        api_key: "my_api_key"

      # Somewhere in your application. Maybe lib/my_app/mailer.ex
      defmodule MyApp.Mailer do
        # Adds deliver/1 and deliver_later/1
        use Bamboo.Mailer, otp_app: :my_app
      end

      # Set up your emails
      defmodule MyApp.Email do
        use Bamboo.Email

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
          Email.welcome_email |> Mailer.deliver
        end
      end
  """
  require Logger

  alias Bamboo.Formatter

  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      config = Bamboo.Mailer.parse_opts(__MODULE__, opts)

      @adapter config.adapter
      @config config

      def deliver(email) do
        Bamboo.Mailer.deliver(@adapter, email, @config)
      end

      def deliver_later(email) do
        Bamboo.Mailer.deliver_later(@adapter, email, @config)
      end
    end
  end

  @doc false
  def deliver(adapter, email, config) do
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

    adapter.deliver_later(email, config)
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
    email |> validate_recipients |> normalize_addresses
  end

  defp validate_recipients(email) do
    if email.to == nil && email.cc == nil && email.bcc == nil do
      raise Bamboo.NilRecipientsError, email
    else
      email
    end
  end

  @doc """
  Wraps to, cc and bcc addresses in a list and normalizes email addresses.

  Email normalization/formatting is done by the [Bamboo.Formatter] protocol.
  """
  def normalize_addresses(email) do
    %{email |
      from: normalize(email.from, :from),
      to: normalize(List.wrap(email.to), :to),
      cc: normalize(List.wrap(email.cc), :cc),
      bcc: normalize(List.wrap(email.bcc), :bcc)
    }
  end

  defp normalize(nil, :from) do
    raise Bamboo.EmptyFromAddressError, nil
  end

  defp normalize(record, type) do
    Formatter.format_email_address(record, %{type: type})
  end

  @doc false
  def parse_opts(mailer, opts) do
    otp_app = Keyword.fetch!(opts, :otp_app)
    Application.get_env(otp_app, mailer) |> Enum.into(%{})
  end
end

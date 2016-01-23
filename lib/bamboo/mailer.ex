defmodule Bamboo.Mailer do
  require Logger

  alias Bamboo.Formatter

  defmodule NoRecipientError do
    defexception [:message]

    def exception(email) do
      message = """
      There was a recipient accidentally set to nil. If you meant to set the
      to, cc or bcc fields to send to no one, set it to an empty list [] instead.

      Recipients:

      To - #{inspect email.to}
      Cc - #{inspect email.cc}
      Bcc - #{inspect email.bcc}

      Full email - #{inspect email, limit: :infinity}
      """
      %NoRecipientError{message: message}
    end
  end

  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      %{adapter: adapter, config: config} = Bamboo.Mailer.parse_opts(__MODULE__, opts)

      @adapter adapter
      @config config

      def deliver(email) do
        Bamboo.Mailer.deliver(@adapter, email, @config)
      end

      def deliver_async(email) do
        Bamboo.Mailer.deliver_async(@adapter, email, @config)
      end
    end
  end

  def deliver(adapter, email, config) do
    email |> validate_and_normalize |> adapter.deliver(config)
  end

  def deliver_async(adapter, email, config) do
    email |> validate_and_normalize |> adapter.deliver_async(config)
  end

  defp validate_and_normalize(email) do
    email = email |> validate_recipients |> normalize_addresses
    debug(email)
    email
  end

  defp validate_recipients(%{to: to, cc: cc, bcc: bcc} = email) when is_nil(to) or is_nil(cc) or is_nil(bcc) do
    raise NoRecipientError, email
  end
  defp validate_recipients(email), do: email

  defp debug(email) do
    Logger.debug """
    Sending email with Bamboo:

    #{inspect email, limit: :infinity}
    """
  end

  def normalize_addresses(email) do
    %{email |
      from: normalize(email.from),
      to: normalize(List.wrap(email.to)),
      cc: normalize(List.wrap(email.cc)),
      bcc: normalize(List.wrap(email.bcc))
    }
  end

  defp normalize(nil), do: %{name: nil, address: nil}
  defp normalize(record) do
    Formatter.format_recipient(record)
  end

  def parse_opts(mailer, opts) do
    otp_app = Keyword.fetch!(opts, :otp_app)
    config = Application.get_env(otp_app, mailer)
    adapter = Keyword.fetch!(config, :adapter)

    %{adapter: adapter, config: config}
  end
end

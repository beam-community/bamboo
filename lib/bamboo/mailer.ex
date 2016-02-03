defmodule Bamboo.Mailer do
  require Logger

  alias Bamboo.Formatter

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
    email = email |> Bamboo.Mailer.normalize_addresses

    debug(email)
    adapter.deliver(email, config)
  end

  def deliver_async(adapter, email, config) do
    email = email |> Bamboo.Mailer.normalize_addresses

    debug(email)
    adapter.deliver_async(email, config)
  end

  defp debug(email) do
    Logger.debug """
    Sending email with Bamboo:

    #{inspect email, limit: :infinity}
    """
  end

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

  def parse_opts(mailer, opts) do
    otp_app = Keyword.fetch!(opts, :otp_app)
    config = Application.get_env(otp_app, mailer)
    adapter = Keyword.fetch!(config, :adapter)

    %{adapter: adapter, config: config}
  end
end

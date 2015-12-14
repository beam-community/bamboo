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

    debug(email, config)
    adapter.deliver(email, config)
  end

  def deliver_async(adapter, email, config) do
    email = email |> Bamboo.Mailer.normalize_addresses

    debug(email, config)
    adapter.deliver_async(email, config)
  end

  defp debug(email, config) do
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

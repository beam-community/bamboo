defmodule Bamboo.Mailer do
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
        Task.async(fn ->
          deliver(email)
        end)
      end
    end
  end

  def deliver(adapter, email, config) do
    email = email |> Bamboo.Mailer.normalize_addresses

    adapter.deliver(email, config)
  end

  def normalize_addresses(email) do
    %{email |
      from: normalize(email.from),
      to: normalize(List.wrap(email.to)),
      cc: normalize(List.wrap(email.cc)),
      bcc: normalize(List.wrap(email.bcc))
    }
  end

  defp normalize(emails) when is_list(emails) do
    emails |> Enum.map(&normalize/1)
  end
  defp normalize(nil), do: %{name: nil, address: nil}
  defp normalize(record), do: Formatter.format_recipient(record)

  def parse_opts(mailer, opts) do
    otp_app = Keyword.fetch!(opts, :otp_app)
    config = Application.get_env(otp_app, mailer)
    adapter = Keyword.fetch!(config, :adapter)

    %{adapter: adapter, config: config}
  end
end

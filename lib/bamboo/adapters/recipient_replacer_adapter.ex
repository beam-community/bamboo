defmodule Bamboo.RecipientReplacerAdapter do
  @moduledoc """
  Replaces to addresses with a provided recipients list.

  It provides a wrapper for any other mailer adapter, usefull when working on releases
  machine with real email address. It simply replaces `to` addresses
  with the provided list of addresses and set original values for `to`, `cc` and `bcc`
  in headers.

  ### Doesn't support adapters without attachments_support

  ## Example config

      # Typically done in config/staging.exs
      config :my_app, MyAppMailer.
        adapter: Bamboo.RecipientReplacerAdapter,
        inner_adapter: Bamboo.SendGridAdapter,
        recipient_replacements: ["user-1@example.com", "user-2@example.com"],
        ...

      # Define a Mailer. Typically in lib/my_app/mailer.ex
      defmodule MyApp.Mailer do
        use Bamboo.Mailer, otp_app: :my_app
      end
  """

  import Bamboo.Email, only: [put_header: 3]

  defmodule(AdapterNotSupportedError, do: defexception([:message]))

  @behaviour Bamboo.Adapter

  @doc false
  def deliver(email, config) do
    original_to = Map.get(email, :to, [])
    original_cc = Map.get(email, :cc, [])
    original_bcc = Map.get(email, :bcc, [])

    adapter = config.inner_adapter

    if not adapter.supports_attachments?() do
      raise AdapterNotSupportedError,
            "RecipientReplacerAdapter supports only adapters that support attachments"
    end

    recipients_list =
      config.recipient_replacements
      |> Enum.map(&{nil, &1})

    email =
      email
      |> Map.put(:to, recipients_list)
      |> Map.put(:cc, [])
      |> Map.put(:bcc, [])
      |> put_header("X-Real-To", convert_recipients_list(original_to))
      |> put_header("X-Real-Cc", convert_recipients_list(original_cc))
      |> put_header("X-Real-Bcc", convert_recipients_list(original_bcc))

    adapter.deliver(email, config)
  end

  @doc false
  def handle_config(config) do
    adapter = config.inner_adapter

    adapter.handle_config(config)
  end

  @doc false
  def supports_attachments?, do: true

  defp convert_recipients_list(recipients_list) do
    Enum.map(recipients_list, fn {name, address} ->
      case name do
        nil -> address
        name -> "<#{name}>#{address}"
      end
    end)
    |> Enum.join(",")
  end
end

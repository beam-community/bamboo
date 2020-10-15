defmodule Bamboo.LocalAdapter do
  @moduledoc """
  Stores emails locally. Can be queried to see sent emails.

  Use this adapter for storing emails locally instead of sending them. Emails
  are stored and can be read from `Bamboo.SentEmail`. Typically this adapter is
  used in the dev environment so emails are not delivered to real email
  addresses.

  You can use this adapter along with `Bamboo.SentEmailViewerPlug` to view
  emails in the browser.

  If you want to open a new browser window for every new email, set the option
  `open_email_in_browser_url` to your preview path.

  ## Example config

      # In config/config.exs, or config/dev.exs, etc.
      config :my_app, MyApp.Mailer,
        adapter: Bamboo.LocalAdapter,
        open_email_in_browser_url: "http://localhost:4000/sent_emails" # optional

      # Define a Mailer. Maybe in lib/my_app/mailer.ex
      defmodule MyApp.Mailer do
        use Bamboo.Mailer, otp_app: :my_app
      end
  """

  alias Bamboo.SentEmail

  @behaviour Bamboo.Adapter

  @doc "Adds email to `Bamboo.SentEmail`, can automatically open it in new browser tab"
  def deliver(email, %{open_email_in_browser_url: open_email_in_browser_url}) do
    %{private: %{local_adapter_id: local_adapter_id}} = SentEmail.push(email)
    open_url_in_browser("#{open_email_in_browser_url}/#{local_adapter_id}")
  end

  def deliver(email, _config) do
    SentEmail.push(email)
  end

  def handle_config(config), do: config

  def supports_attachments?, do: true

  defp open_url_in_browser(url) when is_binary(url) do
    case :os.type() do
      {:unix, :darwin} -> System.cmd("open", [url])
      {:unix, :linux} -> System.cmd("xdg-open", [url])
      {:win32, _} -> System.cmd("explorer", [url])
      {_, _} -> raise "Your os is not supported."
    end
  end

  defp open_url_in_browser(_url), do: raise("Only strings are supported as url")
end

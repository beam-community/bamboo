defmodule Bamboo.LocalAdapter do
  @moduledoc """
  Stores emails locally. Can be queried to see sent emails.

  Use this adapter for storing emails locally instead of sending them. Emails
  are stored and can be read from [Bamboo.SentEmail](Bamboo.SentEmail.html).
  Typically this adapter is used in the dev environment so emails are not
  delivered to real email addresses.

  ## Example config

      # In config/config.exs, or config/dev.exs, etc.
      config :my_app, MyApp.Mailer,
        adapter: Bamboo.LocalAdapter

      # Define a Mailer. Maybe in lib/my_app/mailer.ex
      defmodule MyApp.Mailer do
        use Bamboo.Mailer, otp_app: :my_app
      end
  """

  alias Bamboo.SentEmail

  @behaviour Bamboo.Adapter

  @doc "Adds email to Bamboo.SentEmail"
  def deliver_now(email, _config) do
    SentEmail.push(email)
  end

  def handle_config(config), do: config
end

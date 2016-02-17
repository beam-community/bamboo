defmodule Bamboo.TestAdapter do
  @moduledoc """
  Used for testing email delivery

  No emails are sent, instead a message is sent to the current process and can
  be asserted on with helpers from [Bamboo.Test](Bamboo.Test.html).

  ## Example config

      # Typically done in config/test.exs
      config :my_app, MyApp.Mailer,
        adapter: Bamboo.TestAdapter

      # Define a Mailer. Maybe in lib/my_app/mailer.ex
      defmodule MyApp.Mailer do
        use Bamboo.Mailer, otp_app: :my_app
      end
  """

  @behaviour Bamboo.Adapter

  @doc false
  def deliver(email, _config) do
    send self(), {:delivered_email, email}
  end

  def handle_config(config) do
    case config[:deliver_later_strategy] do
      nil ->
	Map.put(config, :deliver_later_strategy, Bamboo.ImmediateDeliveryStrategy)
      Bamboo.ImmediateDeliveryStrategy ->
        config
      _ ->
        raise ArgumentError, """
        Bamboo.TestAdapter requires that the deliver_later_strategy is
	Bamboo.ImmediateDeliveryStrategy

        Instead it got: #{inspect config[:deliver_later_strategy]}

        Please remove the deliver_later_strategy from your config options, or
	set it to Bamboo.ImmediateDeliveryStrategy.
        """
    end
  end
end

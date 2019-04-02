defmodule Bamboo.TestAdapter do
  @moduledoc """
  Used for testing email delivery.

  No emails are sent, instead a message is sent to the current process and can
  be asserted on with helpers from `Bamboo.Test`.

  ## Example config

      # Typically done in config/test.exs
      config :my_app, MyApp.Mailer,
        adapter: Bamboo.TestAdapter

      # Define a Mailer. Typically in lib/my_app/mailer.ex
      defmodule MyApp.Mailer do
        use Bamboo.Mailer, otp_app: :my_app
      end
  """

  @behaviour Bamboo.Adapter

  @doc false
  def deliver(email, _config) do
    email = clean_assigns(email)
    send(test_process(), {:delivered_email, email})
  end

  defp test_process do
    Application.get_env(:bamboo, :shared_test_process) || self()
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

        Instead it got: #{inspect(config[:deliver_later_strategy])}

        Please remove the deliver_later_strategy from your config options, or
        set it to Bamboo.ImmediateDeliveryStrategy.
        """
    end
  end

  @doc false
  def clean_assigns(email) do
    %{email | assigns: :assigns_removed_for_testing}
  end

  @doc false
  def supports_attachments?, do: true
end

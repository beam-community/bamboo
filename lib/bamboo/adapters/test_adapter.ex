defmodule Bamboo.TestAdapter do
  @moduledoc """
  Used for testing email delivery.

  No emails are sent, instead a message is sent to the current process and to
  its caller processes, and can be asserted on with helpers from `Bamboo.Test`.

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

    for pid <- test_processes() do
      send(pid, {:delivered_email, email})
    end

    {:ok, email}
  end

  defp test_processes do
    if pid = Application.get_env(:bamboo, :shared_test_process) do
      [pid]
    else
      Enum.uniq([self() | List.wrap(Process.get(:"$callers"))])
    end
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

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

  use GenServer

  @doc false
  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @doc """
  Forward messages sent in `from_pid` to `to_pid`. This provides a way to
  write tests that send emails in other processes without resorting to shared
  mode (which cannot be used with async tests).

  To enable this feature, the `Bamboo.TestAdapter` GenServer must be started in
  your `test/test_helper.exs`:

      {:ok, _} = Supervisor.start_link([Bamboo.TestAdapter], strategy: :one_for_one)

  You must then have a way to find out the pid of the process that is sending
  the email and forward it to the process that is running your test.

  For example, when running browser tests with Pheonix, you can configure
  [Phoenix.Ecto.SQL.Sandbox](https://hexdocs.pm/phoenix_ecto/4.3.0/Phoenix.Ecto.SQL.Sandbox.html#content)
  to achieve this.

  In `config/test.exs`:

      config :your_app, :sandbox, Ecto.Adapters.SQL.Sandbox

  In `lib/your_app_web/endpoint.ex`:

      if sandbox = Application.get_env(:your_app, :sandbox) do
        plug Phoenix.Ecto.SQL.Sandbox, sandbox: sandbox
      end

  Now add `test/support/sandbox.ex`:

      defmodule YourApp.Sandbox do
        def allow(repo, owner_pid, child_pid) do
          # Delegate to the Ecto sandbox
          Ecto.Adapters.SQL.Sandbox.allow(repo, owner_pid, child_pid)

          # Forward emails back to the test process
          Bamboo.TestAdapter.forward(child_pid, owner_pid)
        end
      end
  """
  def forward(from_pid, to_pid) do
    :ok = GenServer.call(__MODULE__, {:put_forward, from_pid, to_pid})
  end

  @doc false
  def init(:ok) do
    {:ok, %{forwards: %{}}}
  end

  @doc false
  def handle_call({:put_forward, from_pid, to_pid}, _from, state) do
    {:reply, :ok, put_in(state.forwards[from_pid], to_pid)}
  end

  @doc false
  def handle_call({:get_forward, from_pid}, _from, state) do
    {:reply, state.forwards[from_pid], state}
  end

  @doc false
  def deliver(email, _config) do
    email = clean_assigns(email)
    send(test_process(), {:delivered_email, email})
    {:ok, email}
  end

  defp test_process do
    Application.get_env(:bamboo, :shared_test_process) || forward_pid() || self()
  end

  defp forward_pid do
    if GenServer.whereis(__MODULE__) do
      GenServer.call(__MODULE__, {:get_forward, self()})
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

defmodule Bamboo.Strategies.TaskSupervisor do
  @behaviour Bamboo.Strategy
  @supervisor_name Bamboo.TaskSupervior

  @moduledoc """
  Default strategy. Sends an email in the background using Task.Supervisor

  This is the default strategy because it is the simplest to get started with.
  This strategy uses a Task.Supervisor to monitor the delivery. Deliveries that
  fail will raise, but will not be retried.

  To use this strategy, the Bamboo.TaskSupervior must be added to your
  supervisor. See the docs for `child_spec` or check out the README.
  """

  @doc false
  def deliver_later(adapter, email, config) do
    Task.Supervisor.start_child @supervisor_name, fn ->
      adapter.deliver(email, config)
    end
  end

  @doc """
  Child spec for use in your supervisor

  ## Example

      # Usually in lib/my_app_name/my_app_name.ex
      def start(_type, _args) do
        import Supervisor.Spec

        children = [
          # Add the supervisor that handles deliver_later calls
          Bamboo.Strategies.TaskSupervisor.child_spec
        ]

        # This part is usually already there.
        opts = [strategy: :one_for_one, name: MyApp.Supervisor]
        Supervisor.start_link(children, opts)
      end
  """
  def child_spec do
    Supervisor.Spec.supervisor(
      Task.Supervisor,
      [[name: @supervisor_name]]
    )
  end
end

defmodule Bamboo.TaskSupervisorStrategy do
  @behaviour Bamboo.DeliverLaterStrategy

  @moduledoc """
  Default strategy. Sends an email in the background using `Task.Supervisor`.

  This is the default strategy when calling `deliver_later` because it is the
  simplest to get started with. This strategy uses a `Task.Supervisor` to monitor
  the delivery. Deliveries that fail will raise, but will not be retried, and
  will not bring down the calling process.

  ## Why use it?

  Sending emails can often take time and may fail. If you are sending email
  during a web request (for instance, sending a welcome email), you probably
  don't want to make your users wait the extra time for the welcome email to send.
  Instead you can use `deliver_later/1` and it will be delivered in the background
  so web requests remain snappy.
  """

  @doc false
  def deliver_later(adapter, email, config) do
    Task.Supervisor.start_child(supervisor_name(), fn ->
      adapter.deliver(email, config)
    end)
  end

  def supervisor_name do
    Bamboo.TaskSupervisor
  end

  @doc false
  def child_spec do
    raise """
    Bamboo.TaskSupervisorStrategy is now automatically started by the :bamboo application.

    Please remove the call to Bamboo.TaskSupervisorStrategy.child_spec
    """
  end
end

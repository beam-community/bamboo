defmodule Bamboo.ImmediateDeliveryStrategy do
  @moduledoc """
  Strategy for deliver_later that sends the email immediately.

  This strategy is used and required by the `Bamboo.LocalAdapter` and `Bamboo.TestAdapter`.
  """

  @behaviour Bamboo.DeliverLaterStrategy

  @doc false
  def deliver_later(adapter, email, config) do
    adapter.deliver(email, config)
  end
end

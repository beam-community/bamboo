defmodule Bamboo.Strategies.ImmediateDelivery do
  @moduledoc """
  Strategy that sends the email immediately. Useful for testing.

  This strategy is used and required by the Bamboo.Adapters.Local and
  Bamboo.Adapters.Test
  """

  @behaviour Bamboo.Strategy

  def deliver_later(adapter, email, config) do
    adapter.deliver(email, config)
  end
end

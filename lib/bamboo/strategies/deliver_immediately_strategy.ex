defmodule Bamboo.DeliverImmediatelyStrategy do
  @moduledoc """
  Strategy that sends the email immediately. Useful for testing.

  This strategy is used and required by the Bamboo.LocalAdapter and Bamboo.TestAdapter.
  """

  @behaviour Bamboo.DeliverLaterStrategy

  def deliver_later(adapter, email, config) do
    adapter.deliver(email, config)
  end
end

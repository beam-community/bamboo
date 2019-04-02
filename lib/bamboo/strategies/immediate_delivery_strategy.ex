defmodule Bamboo.ImmediateDeliveryStrategy do
  @moduledoc """
  Strategy for `Bamboo.Mailer.deliver_later/1` that sends the email
  immediately.

  This strategy is used and required by the `Bamboo.LocalAdapter` and
  `Bamboo.TestAdapter`.
  """

  @behaviour Bamboo.DeliverLaterStrategy

  @doc false
  def deliver_later(adapter, email, config) do
    adapter.deliver(email, config)
  end
end

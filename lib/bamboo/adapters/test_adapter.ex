defmodule Bamboo.TestAdapter do
  @behaviour Bamboo.Adapter

  def deliver(email, _config) do
    send self(), {:delivered_email, email}
  end

  def deliver_async(email, _config) do
    deliver(email, nil)
    Task.async(fn -> :ok end)
  end
end

defmodule Bamboo.LocalAdapter do
  alias Bamboo.SentEmail

  def deliver(email, _config) do
    SentEmail.push(email)
  end

  def deliver_async(email, _config) do
    deliver(email, nil)
    Task.async(fn -> end)
  end
end

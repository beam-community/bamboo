defmodule Bamboo.TestAdapter do
  alias Bamboo.TestMailbox

  def deliver(email, _config) do
    TestMailbox.push(email)
  end

  def deliver_async(email, _config) do
    deliver(email, nil)
    Task.async(fn -> end)
  end
end

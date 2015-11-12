defmodule Bamboo.TestAdapter do
  alias Bamboo.TestMailbox

  def deliver(email, _config) do
    TestMailbox.push(email)
  end
end

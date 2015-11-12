defmodule Bamboo do
  use Application

  def start(_type, _args), do: Bamboo.TestMailbox.start_link
end

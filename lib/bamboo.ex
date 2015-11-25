defmodule Bamboo do
  use Application

  def start(_type, _args), do: Bamboo.SentEmail.start_link
end

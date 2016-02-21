defmodule Bamboo.Adapters.LocalTest do
  use ExUnit.Case
  alias Bamboo.SentEmail
  alias Bamboo.Adapters.Local
  import Bamboo.Email, only: [new_email: 0, new_email: 1]

  @config %{}

  setup do
    SentEmail.reset
    :ok
  end

  test "sent emails has emails that were delivered synchronously" do
    email = new_email(subject: "This is my email")

    email |> Local.deliver(@config)

    assert SentEmail.all == [email]
  end
end

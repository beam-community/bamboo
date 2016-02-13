defmodule Bamboo.LocalAdapterTest do
  use ExUnit.Case
  alias Bamboo.SentEmail
  alias Bamboo.LocalAdapter
  import Bamboo.Email, only: [new_email: 0, new_email: 1]

  @config %{}

  setup do
    SentEmail.reset
    :ok
  end

  test "sent emails has emails that were delivered synchronously" do
    email = new_email(subject: "This is my email")

    email |> LocalAdapter.deliver(@config)

    assert SentEmail.all == [email]
  end

  test "handle_config makes sure that the DeliverImmediatelyStrategy is used" do
    new_config = LocalAdapter.handle_config(%{})
    assert new_config.deliver_later_strategy == Bamboo.DeliverImmediatelyStrategy

    new_config = LocalAdapter.handle_config(%{deliver_later_strategy: nil})
    assert new_config.deliver_later_strategy == Bamboo.DeliverImmediatelyStrategy

    assert_raise ArgumentError, ~r/deliver_later_strategy/, fn ->
      LocalAdapter.handle_config(%{deliver_later_strategy: FooStrategy})
    end
  end
end

defmodule Bamboo.LocalAdapterTest do
  use ExUnit.Case
  alias Bamboo.SentEmail
  alias Bamboo.LocalAdapter
  import Bamboo.Email, only: [new_email: 0, new_email: 1]

  @config []

  setup do
    SentEmail.reset
    :ok
  end

  test "sent emails has emails that were delivered synchronously" do
    email = new_email(subject: "This is my email")

    email |> LocalAdapter.deliver(@config)

    assert SentEmail.all == [email]
  end

  test "deliver_later puts email in the mailbox immediately" do
    email = new_email(subject: "This is my email")

    email |> LocalAdapter.deliver_later(@config)

    assert SentEmail.all == [email]
  end

  test "deliver_later returns a task that can be awaited upon" do
    email = new_email(subject: "This is my email")

    task = email |> LocalAdapter.deliver_later(@config)

    Task.await(task)
    assert SentEmail.all == [email]
  end
end

defmodule Bamboo.LocalAdapterTest do
  use ExUnit.Case
  alias Bamboo.SentEmail
  alias Bamboo.LocalAdapter
  import Bamboo.Email, only: [new_email: 1]

  @config %{}

  setup do
    SentEmail.reset
    :ok
  end

  test "sent emails has emails that were delivered synchronously" do
    email = new_email(subject: "This is my email")

    email |> LocalAdapter.deliver(@config)

    assert [%Bamboo.Email{subject: "This is my email"}] = SentEmail.all
  end
end

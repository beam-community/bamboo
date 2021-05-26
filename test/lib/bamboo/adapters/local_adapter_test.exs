defmodule Bamboo.LocalAdapterTest do
  use ExUnit.Case
  alias Bamboo.SentEmail
  alias Bamboo.LocalAdapter
  import Bamboo.Email, only: [new_email: 1]

  @config %{}

  setup do
    SentEmail.reset()
    :ok
  end

  test "sent emails has emails that were delivered synchronously" do
    email = new_email(subject: "This is my email")

    {:ok, _response} = email |> LocalAdapter.deliver(@config)

    assert [%Bamboo.Email{subject: "This is my email"}] = SentEmail.all()
  end

  test "using open_email_in_browser_url doesn't raise an error" do
    email = new_email(subject: "This is my email")

    assert {:ok, _response} =
             email |> LocalAdapter.deliver(%{open_email_in_browser_url: "test://"})
  end
end

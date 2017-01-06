defmodule Bamboo.SentEmailTest do
  use ExUnit.Case
  alias Bamboo.SentEmail

  import Bamboo.Email

  setup do
    Bamboo.SentEmail.reset
    :ok
  end

  test "get_id gets the emails id" do
    email = new_email() |> put_private(:local_adapter_id, 1)

    assert SentEmail.get_id(email) == 1
  end

  test "raises when trying to get id from something that isn't an email" do
    assert_raise RuntimeError, ~r/expected a %Bamboo.Email{}/, fn ->
      SentEmail.get_id("string")
    end
  end

  test "raises helpful message if the id is not set" do
    email = new_email()

    assert_raise RuntimeError, ~r/no id was present/, fn ->
      SentEmail.get_id(email)
    end
  end

  test "gets an email by id" do
    pushed_email = SentEmail.push(new_email(subject: "Something"))

    email = pushed_email |> SentEmail.get_id |> SentEmail.get

    assert %Bamboo.Email{subject: "Something"} = email
  end

  test "get is case-insensitive" do
    pushed_email = SentEmail.push(new_email(subject: "Something"))

    id = SentEmail.get_id(pushed_email)

    assert pushed_email == id |> String.upcase   |> SentEmail.get
    assert pushed_email == id |> String.downcase |> SentEmail.get
  end

  test "returns nil when getting email with no matching id" do
    assert SentEmail.get("non_existent_id") == nil
  end

  test "raises if there is no email with that id" do
    assert_raise Bamboo.SentEmail.NoDeliveriesError, fn ->
      SentEmail.get!("non_existent_id")
    end
  end

  test "all/0 is empty if no emails have been sent" do
    assert SentEmail.all == []
  end

  test "one/0 returns an email if there is one email in the mailbox" do
    email = new_email(subject: "Something")

    SentEmail.push(email)

    assert %Bamboo.Email{subject: "Something"} = SentEmail.one
  end

  test "one/0 raises if there are no emails in the mailbox" do
    assert_raise SentEmail.NoDeliveriesError, fn ->
      SentEmail.one
    end
  end

  test "one/0 raises if there are 2 or more emails in the mailbox" do
    SentEmail.push(new_email())
    SentEmail.push(new_email())

    assert_raise SentEmail.DeliveriesError, fn ->
      SentEmail.one
    end
  end

  test "pushes emails and gives them an id" do
    email = new_email(subject: "Something")

    SentEmail.push(email)

    assert [%{subject: "Something"}] = SentEmail.all
    assert has_id?(SentEmail.one)
  end

  defp has_id?(email) do
    email |> SentEmail.get_id |> String.length == 16
  end

  test "reset/0 removes all emails from the mailbox" do
    SentEmail.push(new_email())

    SentEmail.reset

    assert SentEmail.all == []
  end
end

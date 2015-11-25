defmodule Bamboo.SentEmailTest do
  use ExUnit.Case

  import Bamboo.Email
  alias Bamboo.SentEmail

  setup do
    SentEmail.reset
  end

  test "all/0 is empty if no emails have been sent" do
    assert SentEmail.all == []
  end

  test "one/0 returns an email if there is one email in the mailbox" do
    email = new_email(subject: "Something")

    SentEmail.push(email)

    assert SentEmail.one == email
  end

  test "one/0 raises if there are no emails in the mailbox" do
    assert_raise SentEmail.NoDeliveriesError, fn ->
      SentEmail.one
    end
  end

  test "one/0 raises if there are 2 or more emails in the mailbox" do
    SentEmail.push(new_email)
    SentEmail.push(new_email)

    assert_raise SentEmail.DeliveriesError, fn ->
      SentEmail.one
    end
  end

  test "push/1 adds emails to all" do
    email = new_email(subject: "Something")

    SentEmail.push(email)

    assert SentEmail.all == [email]
  end

  test "reset/0 removes all emails from the mailbox" do
    SentEmail.push(new_email)

    SentEmail.reset

    assert SentEmail.all == []
  end
end

defmodule Bamboo.TestMailboxTest do
  use ExUnit.Case

  import Bamboo.Email
  alias Bamboo.TestMailbox

  setup do
    TestMailbox.reset
  end

  test "deliveries is empty if no emails have been sent" do
    assert TestMailbox.deliveries == []
  end

  test "one/0 returns an email if there is one email in the mailbox" do
    email = new_email(subject: "Something")

    TestMailbox.push(email)

    assert TestMailbox.one == email
  end

  test "one/0 raises if there are no emails in the mailbox" do
    assert_raise TestMailbox.NoDeliveriesError, fn ->
      TestMailbox.one
    end
  end

  test "one/0 raises if there are 2 or more emails in the mailbox" do
    TestMailbox.push(new_email)
    TestMailbox.push(new_email)

    assert_raise TestMailbox.DeliveriesError, fn ->
      TestMailbox.one
    end
  end

  test "push/1 adds emails to deliveries" do
    email = new_email(subject: "Something")

    TestMailbox.push(email)

    assert TestMailbox.deliveries == [email]
  end

  test "reset/0 removes all emails from the mailbox" do
    TestMailbox.push(new_email)

    TestMailbox.reset

    assert TestMailbox.deliveries == []
  end
end

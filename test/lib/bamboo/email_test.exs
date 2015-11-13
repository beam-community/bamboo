defmodule Bamboo.EmailTest do
  use ExUnit.Case

  import Bamboo.Email

  test "new_email/1 returns an Email struct" do
    assert new_email == %Bamboo.Email{
      from: nil,
      to: nil,
      cc: nil,
      bcc: nil,
      subject: nil,
      html_body: nil,
      text_body: nil,
      headers: %{}
    }
  end

  test "new_email/1 can override email attributes with lists or maps" do
    email_attrs = %{to: "foo@bar.com", subject: "Cool Email"}
    email = new_email(email_attrs)
    assert email.to == "foo@bar.com"
    assert email.subject == "Cool Email"

    email_attrs = [to: "foo@bar.com", subject: "Cool Email"]
    email =  new_email(email_attrs)
    assert email.to == "foo@bar.com"
    assert email.subject == "Cool Email"
  end

  test "can pipe updates with functions" do
    email = new_email
      |> from("me@foo.com")
      |> to("to@example.com")
      |> cc("cc@example.com")
      |> bcc("bcc@foo.com")
      |> subject("Flexible Emails")
      |> put_header("Reply-To", "reply@foo.com")

    assert email.from == "me@foo.com"
    assert email.to == "to@example.com"
    assert email.cc == "cc@example.com"
    assert email.bcc == "bcc@foo.com"
    assert email.subject == "Flexible Emails"
    assert email.headers["Reply-To"] == "reply@foo.com"
  end

  test "put_private/3 puts a key and value in the private attribute" do
    email = new_email |> put_private("foo", "bar")

    assert email.private["foo"] == "bar"
  end
end

defmodule Bamboo.EmailTest do
  use ExUnit.Case

  import Bamboo.Email

  test "new_email/1 returns an Email struct" do
    assert new_email() == %Bamboo.Email{
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

  test "get_address gets the address or raises if not normalized" do
    assert get_address({"Paul", "paul@gmail.com"}) == "paul@gmail.com"

    assert_raise RuntimeError, ~r/expected an address/, fn ->
      get_address({})
    end
  end

  test "returns list of all recipients" do
    email = new_email(from: "foo", to: "to@foo.com", cc: "cc@foo.com", bcc: "bcc@foo.com")
      |> Bamboo.Mailer.normalize_addresses

    assert all_recipients(email) == [
      {nil, "to@foo.com"},
      {nil, "cc@foo.com"},
      {nil, "bcc@foo.com"},
    ]
  end

  test "raises if emails are not normalized" do
    assert_raise RuntimeError, ~r/normalized/, fn ->
      email = new_email(to: ["to@foo.com"])
      all_recipients(email)
    end
  end

  test "can pipe updates with functions" do
    email = new_email()
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
    email = new_email() |> put_private("foo", "bar")

    assert email.private["foo"] == "bar"
  end

  describe "put_attachment/2" do
    test "adds an attachment to the attachments list" do
      attachment = %Bamboo.Attachment{filename: "attachment.docx", data: "content"}
      email = new_email() |> put_attachment(attachment)

      assert [%Bamboo.Attachment{filename: "attachment.docx"}] = email.attachments
    end

    test "with no filename throws an error" do
      attachment = %Bamboo.Attachment{filename: nil, data: "content"}

      msg = "You must provide a filename for the attachment, instead got: %Bamboo.Attachment{content_type: nil, data: \"content\", filename: nil, path: nil}"
      assert_raise RuntimeError, msg, fn ->
        new_email() |> put_attachment(attachment)
      end
    end

    test "with no data throws an error" do
      attachment = %Bamboo.Attachment{filename: "attachment.docx", data: nil}

      msg = "The attachment must contain data, instead got: %Bamboo.Attachment{content_type: nil, data: nil, filename: \"attachment.docx\", path: nil}"
      assert_raise RuntimeError, msg, fn ->
        new_email() |> put_attachment(attachment)
      end
    end
  end

  test "put_attachment/3 adds an attachment to the attachments list" do
    path = Path.join(__DIR__, "../../support/attachment.docx")
    email = new_email() |> put_attachment(path)

    assert [%Bamboo.Attachment{filename: "attachment.docx"}] = email.attachments
  end
end

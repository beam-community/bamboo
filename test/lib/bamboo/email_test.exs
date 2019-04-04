defmodule Bamboo.EmailTest do
  use ExUnit.Case
  import Bamboo.Email
  alias Bamboo.Email

  doctest Bamboo.Email

  test "can pipe updates with functions" do
    email =
      new_email()
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

  describe "new_email/1" do
    test "returns an Email struct" do
      assert new_email() == %Email{
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

    test "can override email attributes with a map" do
      email_attrs = %{to: "foo@bar.com", subject: "Cool Email"}
      email = new_email(email_attrs)

      assert email.to == "foo@bar.com"
      assert email.subject == "Cool Email"
    end

    test "can override email attributes with a list" do
      email_attrs = [to: "foo@bar.com", subject: "Cool Email"]
      email = new_email(email_attrs)

      assert email.to == "foo@bar.com"
      assert email.subject == "Cool Email"
    end
  end

  describe "get_address/1" do
    test "gets the address of a normalized address" do
      assert get_address({"Paul", "paul@gmail.com"}) == "paul@gmail.com"
    end

    test "raises an error for a non-normalized address" do
      assert_raise RuntimeError, ~r/expected an address/, fn -> get_address({}) end
    end
  end

  describe "all_recipients/1" do
    test "returns list of all recipients" do
      email =
        new_email(from: "foo", to: "to@foo.com", cc: "cc@foo.com", bcc: "bcc@foo.com")
        |> Bamboo.Mailer.normalize_addresses()

      assert all_recipients(email) == [
               {nil, "to@foo.com"},
               {nil, "cc@foo.com"},
               {nil, "bcc@foo.com"}
             ]
    end

    test "raises if emails are not normalized" do
      assert_raise RuntimeError, ~r/normalized/, fn ->
        email = new_email(to: ["to@foo.com"])
        all_recipients(email)
      end
    end
  end

  describe "put_header/3" do
    test "adds a field value for a new field name" do
      email =
        %{headers: %{}}
        |> new_email()
        |> Email.put_header("x-hero", "mario")

      assert email.headers == %{"x-hero" => "mario"}
    end

    test "replaces the value for an existing field name" do
      email =
        %{headers: %{"x-hero" => "mario"}}
        |> new_email()
        |> Email.put_header("x-hero", "luigi")

      assert email.headers == %{"x-hero" => "luigi"}
    end

    test "accepts a list as a value" do
      email =
        new_email()
        |> Email.put_header("x-hero", ["mario", "luigi"])

      assert email.headers == %{"x-hero" => ["mario", "luigi"]}
    end

    test "does not change headers for a non-string value" do
      email =
        %{headers: %{}}
        |> new_email()
        |> Email.put_header("x-hero", %{name: "mario"})

      assert email.headers == %{}
    end

    test "does not change headers for a nil value" do
      email =
        %{headers: %{}}
        |> new_email()
        |> Email.put_header("x-hero", nil)

      assert email.headers == %{}
    end
  end

  describe "put_header/3 :combine" do
    test "adds a field value for a new field name" do
      email =
        %{headers: %{}}
        |> new_email()
        |> Email.put_header("x-hero", "mario", :combine)

      assert email.headers == %{"x-hero" => "mario"}
    end

    test "makes the value a list for an existing field name" do
      email =
        %{headers: %{"x-hero" => "mario"}}
        |> new_email()
        |> Email.put_header("x-hero", "luigi", :combine)

      assert email.headers == %{"x-hero" => ["luigi", "mario"]}
    end

    test "adds to a list of field values for an existing field name" do
      email =
        %{headers: %{"x-hero" => ["mario", "luigi"]}}
        |> new_email()
        |> Email.put_header("x-hero", "dk", :combine)

      assert email.headers == %{"x-hero" => ["dk", "mario", "luigi"]}
    end

    test "adds a new list to the list of field values for an existing field name" do
      email =
        %{headers: %{"x-hero" => ["mario", "luigi"]}}
        |> new_email()
        |> Email.put_header("x-hero", ["dk", "yoshi"], :combine)

      assert email.headers == %{"x-hero" => ["dk", "yoshi", "mario", "luigi"]}
    end

    test "does not change headers for a non-string value" do
      email =
        %{headers: %{}}
        |> new_email()
        |> Email.put_header("x-hero", %{name: "mario"}, :combine)

      assert email.headers == %{}
    end

    test "does not change headers for a nil value" do
      email =
        %{headers: %{}}
        |> new_email()
        |> Email.put_header("x-hero", nil, :combine)

      assert email.headers == %{}
    end
  end

  describe "put_private/3" do
    test "put_private/3 puts a key and value in the private attribute" do
      email = new_email() |> put_private("foo", "bar")

      assert email.private["foo"] == "bar"
    end
  end

  describe "put_attachment/2" do
    test "adds an attachment to the attachments list" do
      attachment = %Bamboo.Attachment{filename: "attachment.docx", data: "content"}
      email = new_email() |> put_attachment(attachment)

      assert [%Bamboo.Attachment{filename: "attachment.docx"}] = email.attachments
    end

    test "with no filename throws an error" do
      attachment = %Bamboo.Attachment{filename: nil, data: "content"}

      msg =
        "You must provide a filename for the attachment, instead got: %Bamboo.Attachment{content_type: nil, data: \"content\", filename: nil, path: nil}"

      assert_raise RuntimeError, msg, fn ->
        new_email() |> put_attachment(attachment)
      end
    end

    test "with no data throws an error" do
      attachment = %Bamboo.Attachment{filename: "attachment.docx", data: nil}

      msg =
        "The attachment must contain data, instead got: %Bamboo.Attachment{content_type: nil, data: nil, filename: \"attachment.docx\", path: nil}"

      assert_raise RuntimeError, msg, fn ->
        new_email() |> put_attachment(attachment)
      end
    end
  end

  describe "put_attachment/3" do
    test " adds an attachment to the attachments list" do
      path = Path.join(__DIR__, "../../support/attachment.docx")
      email = new_email() |> put_attachment(path)

      assert [%Bamboo.Attachment{filename: "attachment.docx"}] = email.attachments
    end
  end
end

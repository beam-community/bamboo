defmodule Bamboo.MailgunHelperTest do
  use ExUnit.Case
  import Bamboo.Email
  alias Bamboo.MailgunHelper

  test "tag/2 puts a tag in private" do
    email = new_email() |> MailgunHelper.tag("new-tag")

    assert Map.get(Map.get(email, :private, %{}), :"o:tag", nil) == "new-tag"
  end

  test "deliverytime/2 puts a deliverytime in private" do
    email = new_email() |> MailgunHelper.deliverytime(DateTime.from_unix!(1_422_057_007))

    assert Map.get(Map.get(email, :private, %{}), :"o:deliverytime", nil) == 1_422_057_007
  end

  test "adds template information to mailgun emails" do
    email =
      new_email()
      |> MailgunHelper.template("welcome")

    assert email.private == %{template: "welcome"}
  end

  test "adds template version to mailgun emails" do
    email = new_email() |> MailgunHelper.template_version("v2")
    assert email.private == %{:"t:version" => "v2"}
  end

  test "enables template text" do
    email = new_email() |> MailgunHelper.template_text(true)
    assert email.private == %{:"t:text" => true}
  end

  test "disables template text" do
    email = new_email() |> MailgunHelper.template_text(false)
    assert email.private == %{:"t:text" => false}
  end

  test "disables template text with wrong arg" do
    email = new_email() |> MailgunHelper.template_text("string")
    assert email.private == %{:"t:text" => false}
  end

  test "adds template substitution variables to mailgun emails" do
    email =
      new_email()
      |> MailgunHelper.substitute_variables("var1", "val1")
      |> MailgunHelper.substitute_variables(%{"var2" => "val2", "var3" => "val3"})
      |> MailgunHelper.substitute_variables("var4", "val4")

    assert email.headers
           |> Map.get("X-Mailgun-Variables")
           |> Bamboo.json_library().decode!()
           |> Map.equal?(%{
             "var1" => "val1",
             "var2" => "val2",
             "var3" => "val3",
             "var4" => "val4"
           })
  end

  test "adds recipient variables to mailgun emails" do
    email =
      new_email()
      |> MailgunHelper.recipient_variables(%{
        "user1@example.com" => %{unique_id: "ABC123456789"}
      })

    assert email.private == %{
             mailgun_recipient_variables:
               "{\"user1@example.com\":{\"unique_id\":\"ABC123456789\"}}"
           }
  end
end

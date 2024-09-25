defmodule Bamboo.MailgunHelperTest do
  use ExUnit.Case

  import Bamboo.Email

  alias Bamboo.MailgunHelper

  test "tag/2 puts a tag in private" do
    email = MailgunHelper.tag(new_email(), "new-tag")

    assert email |> Map.get(:private, %{}) |> Map.get(:"o:tag", nil) == "new-tag"
  end

  test "deliverytime/2 puts a deliverytime in private" do
    email = MailgunHelper.deliverytime(new_email(), DateTime.from_unix!(1_422_057_007))

    assert email |> Map.get(:private, %{}) |> Map.get(:"o:deliverytime", nil) == 1_422_057_007
  end

  test "adds template information to mailgun emails" do
    email = MailgunHelper.template(new_email(), "welcome")

    assert email.private == %{template: "welcome"}
  end

  test "adds template version to mailgun emails" do
    email = MailgunHelper.template_version(new_email(), "v2")
    assert email.private == %{:"t:version" => "v2"}
  end

  test "enables template text" do
    email = MailgunHelper.template_text(new_email(), true)
    assert email.private == %{:"t:text" => true}
  end

  test "disables template text" do
    email = MailgunHelper.template_text(new_email(), false)
    assert email.private == %{:"t:text" => false}
  end

  test "disables template text with wrong arg" do
    email = MailgunHelper.template_text(new_email(), "string")
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
      MailgunHelper.recipient_variables(new_email(), %{
        "user1@example.com" => %{unique_id: "ABC123456789"}
      })

    assert email.private == %{
             mailgun_recipient_variables: "{\"user1@example.com\":{\"unique_id\":\"ABC123456789\"}}"
           }
  end
end

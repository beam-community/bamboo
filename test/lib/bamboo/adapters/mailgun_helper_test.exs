defmodule Bamboo.MailgunHelperTest do
  use ExUnit.Case
  import Bamboo.Email
  alias Bamboo.MailgunHelper

  test "tag/2 puts a tag in private" do
    email = new_email() |> MailgunHelper.tag("new-tag")

    assert Map.get(Map.get(email, :private, %{}), :"o:tag", nil) == "new-tag"
  end

  test "deliverytime/2 puts a deliverytime in private" do
    email = new_email() |> MailgunHelper.deliverytime(~U[2015-01-23 23:50:07Z])

    # DateTime.to_unix(~U[2015-01-23 23:50:07Z]) == 1_422_057_007
    assert Map.get(Map.get(email, :private, %{}), :"o:deliverytime", nil) == 1_422_057_007
  end

  test "adds template information to mailgun emails" do
    email =
      new_email()
      |> MailgunHelper.template("welcome")

    assert email.private == %{template: "welcome"}
  end

  test "adds template substitution variables to mailgun emails" do
    email =
      new_email()
      |> MailgunHelper.substitute_variables("var1", "val1")
      |> MailgunHelper.substitute_variables(%{"var2" => "val2", "var3" => "val3"})
      |> MailgunHelper.substitute_variables("var4", "val4")

    assert email.private == %{
             mailgun_custom_vars: %{
               "var1" => "val1",
               "var2" => "val2",
               "var3" => "val3",
               "var4" => "val4"
             }
           }
  end
end

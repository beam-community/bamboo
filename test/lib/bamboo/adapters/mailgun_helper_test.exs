defmodule Bamboo.MailgunHelperTest do
  use ExUnit.Case
  import Bamboo.Email
  alias Bamboo.MailgunHelper

  # These tests are based mostly on MandrillHelperTest, but seem fragile.
  # They rely on internal structure used by the adapter and helper, and
  # don't (AND CAN'T) look at the resulting email created by MailgunAdapter.to_mailgun_body()
  # without major refactoring.
  # This is better than nothing, though.

  test "tag/2 puts a tag in private" do
    email = new_email() |> MailgunHelper.tag("new-tag")

    assert Map.get(Map.get(email, :private, %{}), :"o:tag", nil) == "new-tag"
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

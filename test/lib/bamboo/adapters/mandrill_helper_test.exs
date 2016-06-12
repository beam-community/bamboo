defmodule Bamboo.MandrillHelperTest do
  use ExUnit.Case
  import Bamboo.Email
  alias Bamboo.MandrillHelper

  test "put_param/3 puts a map in private.message_params" do
    email = new_email |> MandrillHelper.put_param("track_links", true)

    assert email.private.message_params == %{"track_links" => true}
  end

  test "adds tags to mandrill emails" do
    email = new_email |> MandrillHelper.tag("welcome-email")
    assert email.private.message_params == %{"tags" => ["welcome-email"]}

    email = new_email |> MandrillHelper.tag(["welcome-email", "awesome"])
    assert email.private.message_params == %{"tags" => ["welcome-email", "awesome"]}
  end

  test "adds template information to mandrill emails" do
    email = new_email |> MandrillHelper.template("welcome", [%{"name" => "example_name", "content" => "example_content"}])
    assert email.private == %{template_name: "welcome", template_content: [%{"name" => "example_name", "content" => "example_content"}]}

    email = new_email |> MandrillHelper.template("welcome")
    assert email.private == %{template_name: "welcome", template_content: []}
  end
end

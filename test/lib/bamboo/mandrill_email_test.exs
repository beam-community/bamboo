defmodule Bamboo.MandrillEmailTest do
  use ExUnit.Case
  use Bamboo.MandrillEmail
  alias Bamboo.MandrillEmail

  test "put_message_param/3 puts a map in private.message_params" do
    email = new_email |> MandrillEmail.put_message_param("track_links", true)

    assert email.private.message_params == %{"track_links" => true}
  end

  test "adds tags to mandrill emails" do
    email = new_email |> MandrillEmail.tag("welcome-email")
    assert email.private.message_params == %{"tags" => ["welcome-email"]}

    email = new_email |> MandrillEmail.tag(["welcome-email", "awesome"])
    assert email.private.message_params == %{"tags" => ["welcome-email", "awesome"]}
  end
end

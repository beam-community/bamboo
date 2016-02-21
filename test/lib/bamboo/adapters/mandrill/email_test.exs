defmodule Bamboo.Adapters.Mandrill.EmailTest do
  use ExUnit.Case
  import Bamboo.Email
  alias Bamboo.Adapters.Mandrill.Email

  test "put_param/3 puts a map in private.message_params" do
    email = new_email |> Email.put_param("track_links", true)

    assert email.private.message_params == %{"track_links" => true}
  end

  test "adds tags to mandrill emails" do
    email = new_email |> Email.tag("welcome-email")
    assert email.private.message_params == %{"tags" => ["welcome-email"]}

    email = new_email |> Email.tag(["welcome-email", "awesome"])
    assert email.private.message_params == %{"tags" => ["welcome-email", "awesome"]}
  end
end

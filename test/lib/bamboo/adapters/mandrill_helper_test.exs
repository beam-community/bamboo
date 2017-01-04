defmodule Bamboo.MandrillHelperTest do
  use ExUnit.Case
  import Bamboo.Email
  alias Bamboo.MandrillHelper

  test "put_param/3 puts a map in private.message_params" do
    email = new_email() |> MandrillHelper.put_param("track_links", true)

    assert email.private.message_params == %{"track_links" => true}
  end

  test "put_merge_vars/3 puts a list of merge_vars in private.merge_vars" do
    users = [
      %{
        email: "user1@example.com",
        full_name: "User 1"
      },
      %{
        email: "user2@example.com",
        full_name: "User 2"
      }
    ]

    email = MandrillHelper.put_merge_vars new_email(), users, fn(user) ->
      %{full_name: user.full_name}
    end

    assert email.private.message_params == %{"merge_vars" => [
        %{
          rcpt: "user1@example.com",
          vars: [
            %{
              "name": "full_name",
              "content": "User 1"
            }
          ]
        },
        %{
          rcpt: "user2@example.com",
          vars: [
            %{
              "name": "full_name",
              "content": "User 2"
            }
          ]
        }
      ]
    }
  end

  test "adds tags to mandrill emails" do
    email = new_email() |> MandrillHelper.tag("welcome-email")
    assert email.private.message_params == %{"tags" => ["welcome-email"]}

    email = new_email() |> MandrillHelper.tag(["welcome-email", "awesome"])
    assert email.private.message_params == %{"tags" => ["welcome-email", "awesome"]}
  end

  test "adds template information to mandrill emails" do
    email = new_email() |> MandrillHelper.template("welcome", [%{"name" => "example_name", "content" => "example_content"}])
    assert email.private == %{template_name: "welcome", template_content: [%{"name" => "example_name", "content" => "example_content"}]}

    email = new_email() |> MandrillHelper.template("welcome")
    assert email.private == %{template_name: "welcome", template_content: []}
  end
end

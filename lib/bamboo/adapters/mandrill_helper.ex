defmodule Bamboo.MandrillHelper do
  @moduledoc """
  Functions for using features specific to Mandrill e.g. tagging, merge vars, templates
  """

  alias Bamboo.Email

  @doc """
  Put extra message parameters that are used by Mandrill

  Parameters set with this function are sent to Mandrill when used along with
  the Bamboo.MandrillAdapter. You can set things like `important`, `merge_vars`,
  and whatever else you need that the Mandrill API supports.

  ## Example

      email
      |> put_param(email, "track_opens", true)
      |> put_param(email, "mege_vars", "merge_vars": [
        %{
          rcpt: "recipient.email@example.com",
          vars: [
            %{
              "name": "merge2",
              "content": "merge2 content"
            }
          ]
        }
      ])
  """
  def put_param(%Email{private: %{message_params: _}} = email, key, value) do
    put_in(email.private[:message_params][key], value)
  end
  def put_param(email, key, value) do
    email |> Email.put_private(:message_params, %{}) |> put_param(key, value)
  end

  @doc """
  Set a single tag or multiple tags for an email.

  A convenience function for `put_param(email, "tags", ["my-tag"])`

  ## Example

      tag(email, "welcome-email")
      tag(email, ["welcome-email", "marketing"])
  """
  def tag(email, tags) do
    put_param(email, "tags", List.wrap(tags))
  end

  @doc """
  Send emails using Mandrill's template API.

  Setup Mandrill to send using a named template with template content. Use this
  in conjuction with merge vars to offload template rendering to Mandrill. The
  template name specified here must match the template name stored in Mandrill.
  Mandrill's API docs for this can be found [here](https://www.mandrillapp.com/api/docs/messages.JSON.html#method=send-template).

  ## Example

      template(email, "welcome")
      template(email, "welcome", [%{"name" => "Name", "content" => "John"}])
  """
  def template(email, template_name, template_content \\ []) do
    email
    |> Email.put_private(:template_name, template_name)
    |> Email.put_private(:template_content, template_content)
  end
end

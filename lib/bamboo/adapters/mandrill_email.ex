defmodule Bamboo.MandrillEmail do
  @moduledoc """
  Functions for using features specific to Mandrill.
  """

  alias Bamboo.Email

  defmacro __using__(_opts) do
    quote do
      use Bamboo.Email
      alias Bamboo.MandrillEmail
    end
  end

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
  def put_param(%Email{private: %{message_params: params}} = email, key, value) do
    message_params = params |> Map.put(key, value)
    private = email.private
    private = %{private | message_params: message_params}
    %{email | private: private}
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
end

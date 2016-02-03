defmodule Bamboo.MandrillEmail do
  alias Bamboo.Email

  defmacro __using__(_opts) do
    quote do
      import Bamboo.Email
      alias Bamboo.MandrillEmail
    end
  end

  def put_message_param(%Email{private: %{message_params: params}} = email, key, value) do
    message_params = params |> Map.put(key, value)
    private = email.private
    private = %{private | message_params: message_params}
    %{email | private: private}
  end
  def put_message_param(email, key, value) do
    email |> Email.put_private(:message_params, %{}) |> put_message_param(key, value)
  end

  def tag(email, tags) do
    put_message_param(email, "tags", List.wrap(tags))
  end
end

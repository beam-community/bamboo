defmodule Bamboo.MandrillEmail do
  alias Bamboo.Email

  def put_message_param(%Email{private: %{message_params: params}} = email, key, value) do
    message_params = params |> Map.put(key, value)
    private = email.private
    private = %{private | message_params: message_params}
    %{email | private: private}
  end
  def put_message_param(email, key, value) do
    email |> Email.put_private(:message_params, %{}) |> put_message_param(key, value)
  end
end

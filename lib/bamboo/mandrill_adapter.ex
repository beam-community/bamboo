defmodule Bamboo.MandrillAdapter do
  @default_base_uri "https://mandrillapp.com/"
  @send_message_path "api/1.0/messages/send.json"

  def deliver(email, config) do
    api_key = Keyword.fetch!(config, :api_key)
    params = email |> convert_to_mandrill_params(api_key) |> Poison.encode!
    HTTPoison.post("#{base_uri}/#{@send_message_path}", params, headers)
  end

  defp convert_to_mandrill_params(email, api_key) do
    %{api_key: api_key, message: message_params(email)}
  end

  defp message_params(email) do
    %{
      from_email: email.from.address,
      from_name: email.from.name,
      to: recipients(email),
      subject: email.subject,
      text: email.text_body,
      html: email.html_body,
      headers: email.headers
    }
  end

  defp recipients(email) do
    []
    |> add_recipients(email.to, type: "to")
    |> add_recipients(email.cc, type: "cc")
    |> add_recipients(email.bcc, type: "bcc")
  end

  defp add_recipients(recipients, new_recipients, type: recipient_type) do
    Enum.reduce(new_recipients, recipients, fn(recipient, recipients) ->
      recipients ++ [%{
        name: recipient.name,
        email: recipient.address,
        type: recipient_type
      }]
    end)
  end

  defp headers do
    %{"content-type" => "application/json"}
  end

  defp base_uri do
    Application.get_env(:bamboo, :mandrill_base_uri) || @default_base_uri
  end
end

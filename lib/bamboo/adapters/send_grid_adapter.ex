defmodule Bamboo.SendGridAdapter do
  @moduledoc """
  Sends email using SendGrid's JSON API.

  Use this adapter to send emails through SendGrid's API. Requires that an API
  key is set in the config.

  If you would like to add a replyto header to your email, then simply pass it in
  using the header property or put_header function like so:

      put_header("reply-to", "foo@bar.com")

  ## Example config

      # In config/config.exs, or config.prod.exs, etc.
      config :my_app, MyApp.Mailer,
        adapter: Bamboo.SendGridAdapter,
        api_key: "my_api_key"

      # Define a Mailer. Maybe in lib/my_app/mailer.ex
      defmodule MyApp.Mailer do
        use Bamboo.Mailer, otp_app: :my_app
      end
  """

  @service_name "SendGrid"
  @default_base_uri "https://sendgrid.com/v3/"
  @send_message_path "/mail/send"
  @behaviour Bamboo.Adapter

  alias Bamboo.Email
  import Bamboo.ApiError

  def deliver(email, config) do
    api_key = get_key(config)
    body = email |> to_sendgrid_body |> Poison.encode!
    url = [base_uri(), @send_message_path]

    case :hackney.post(url, headers(api_key), body, [:with_body]) do
      {:ok, status, _headers, response} when status > 299 ->
        filtered_params = body |> Poison.decode! |> Map.put("key", "[FILTERED]")
        raise_api_error(@service_name, response, filtered_params)
      {:ok, status, headers, response} ->
        %{status_code: status, headers: headers, body: response}
      {:error, reason} ->
        raise_api_error(inspect(reason))
    end
  end

  @doc false
  def handle_config(config) do
    if config[:api_key] in [nil, ""] do
      raise_api_key_error(config)
    else
      config
    end
  end

  @doc false
  def supports_attachments?, do: true

  defp get_key(config) do
    case Map.get(config, :api_key) do
      nil -> raise_api_key_error(config)
      key -> key
    end
  end

  defp raise_api_key_error(config) do
    raise ArgumentError, """
    There was no API key set for the SendGrid adapter.

    * Here are the config options that were passed in:

    #{inspect config}
    """
  end

  defp headers(api_key) do
    [
      {"Content-Type", "application/json"},
      {"Authorization", "Bearer #{api_key}"},
    ]
  end

  defp to_sendgrid_body(%Email{} = email) do
    %{}
    |> put_from(email)
    |> put_personalization(email)
    |> put_reply_to(email)
    |> put_subject(email)
    |> put_content(email)
    |> put_template_id(email)
    |> put_attachments(email)
  end

  defp put_from(body, %Email{from: from}) do
    Map.put(body, :from, to_address(from))
  end

  defp put_personalization(body, email) do
    Map.put(body, :personalizations, [personalization(email)])
  end

  defp personalization(email) do
    %{}
    |> put_to(email)
    |> put_cc(email)
    |> put_bcc(email)
    |> put_template_substitutions(email)
  end

  defp put_to(body, %Email{to: to}) do
    put_addresses(body, :to, to)
  end

  defp put_cc(body, %Email{cc: []}), do: body
  defp put_cc(body, %Email{cc: cc}) do
    put_addresses(body, :cc, cc)
  end

  defp put_bcc(body, %Email{bcc: []}), do: body
  defp put_bcc(body, %Email{bcc: bcc}) do
    put_addresses(body, :bcc, bcc)
  end

  defp put_reply_to(body, %Email{headers: %{"reply-to" => reply_to}}) do
    Map.put(body, :reply_to, %{email: reply_to})
  end
  defp put_reply_to(body, _), do: body

  defp put_subject(body, %Email{subject: subject}), do: Map.put(body, :subject, subject)

  defp put_content(body, email) do
    Map.put(body, :content, content(email))
  end

  defp content(email) do
    []
    |> put_html_body(email)
    |> put_text_body(email)
  end

  defp put_html_body(list, %Email{html_body: nil}), do: list
  defp put_html_body(list, %Email{html_body: html_body}) do
    [%{type: "text/html", value: html_body} | list]
  end

  defp put_text_body(list, %Email{text_body: nil}), do: list
  defp put_text_body(list, %Email{text_body: text_body}) do
    [%{type: "text/plain", value: text_body} | list]
  end

  defp put_template_id(body, %Email{private: %{send_grid_template: %{template_id: template_id}}} = email) do
    # SendGrid will error with empty content and subject, even while using templates.
    # Sets default `text_body` and `subject` if neither are specified,
    # allowing the consumer to neglect doing so themselves.
    body
    |> ensure_content_provided(email)
    |> ensure_subject_provided(email)
    |> Map.put(:template_id, template_id)
  end
  defp put_template_id(body, _), do: body

  defp put_template_substitutions(body, %Email{private: %{send_grid_template: %{substitutions: substitutions}}}) do
    Map.put(body, :substitutions, substitutions)
  end
  defp put_template_substitutions(body, _), do: body

  defp put_attachments(body, %Email{attachments: []}), do: body
  defp put_attachments(body, %Email{attachments: attachments}) do
    transformed = attachments
    |> Enum.reverse
    |> Enum.map(fn(attachment) ->
      %{
        filename: attachment.filename,
        type: attachment.content_type,
        content: Base.encode64(attachment.data)
      }
    end)
    Map.put(body, :attachments, transformed)
  end

  defp ensure_content_provided(%{content: []} = body, email) do
    put_content(body, %Email{email | text_body: " "})
  end
  defp ensure_content_provided(body, _), do: body

  defp ensure_subject_provided(%{subject: nil} = body, email) do
    put_subject(body, %Email{email | subject: " "})
  end
  defp ensure_subject_provided(body, _), do: body

  defp put_addresses(body, _, []), do: body
  defp put_addresses(body, field, addresses), do: Map.put(body, field, Enum.map(addresses, &to_address/1))

  defp to_address({nil, address}), do: %{email: address}
  defp to_address({"", address}), do: %{email: address}
  defp to_address({name, address}), do: %{email: address, name: name}

  defp base_uri do
    Application.get_env(:bamboo, :sendgrid_base_uri) || @default_base_uri
  end
end

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
        api_key: "my_api_key" # or {:system, "SENDGRID_API_KEY"}

      # To enable sandbox mode (e.g. in development or staging environments),
      # in config/dev.exs or config/prod.exs etc
      config :my_app, MyApp.Mailer, sandbox: true

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
    body = email |> to_sendgrid_body(config) |> Poison.encode!()
    url = [base_uri(), @send_message_path]

    case :hackney.post(url, headers(api_key), body, [:with_body]) do
      {:ok, status, _headers, response} when status > 299 ->
        filtered_params = body |> Poison.decode!() |> Map.put("key", "[FILTERED]")
        raise_api_error(@service_name, response, filtered_params)

      {:ok, status, headers, response} ->
        %{status_code: status, headers: headers, body: response}

      {:error, reason} ->
        raise_api_error(inspect(reason))
    end
  end

  @doc false
  def handle_config(config) do
    # build the api key - will raise if there are errors
    Map.merge(config, %{api_key: get_key(config)})
  end

  @doc false
  def supports_attachments?, do: true

  defp get_key(config) do
    api_key =
      case Map.get(config, :api_key) do
        {:system, var} -> System.get_env(var)
        key -> key
      end

    if api_key in [nil, ""] do
      raise_api_key_error(config)
    else
      api_key
    end
  end

  defp raise_api_key_error(config) do
    raise ArgumentError, """
    There was no API key set for the SendGrid adapter.

    * Here are the config options that were passed in:

    #{inspect(config)}
    """
  end

  defp headers(api_key) do
    [
      {"Content-Type", "application/json"},
      {"Authorization", "Bearer #{api_key}"}
    ]
  end

  defp to_sendgrid_body(%Email{} = email, config) do
    %{}
    |> put_from(email)
    |> put_personalization(email)
    |> put_reply_to(email)
    |> put_subject(email)
    |> put_content(email)
    |> put_template_id(email)
    |> put_attachments(email)
    |> put_categories(email)
    |> put_settings(config)
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
    |> put_custom_args(email)
    |> put_template_substitutions(email)
    |> put_dynamic_template_data(email)
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

  defp put_subject(body, %Email{subject: subject}) when not is_nil(subject),
    do: Map.put(body, :subject, subject)

  defp put_subject(body, _), do: body

  defp put_content(body, email) do
    email_content = content(email)

    if not Enum.empty?(email_content) do
      Map.put(body, :content, content(email))
    else
      body
    end
  end

  defp put_settings(body, %{sandbox: true}), do: Map.put(body, :mail_settings, %{sandbox: true})
  defp put_settings(body, _), do: body

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

  defp put_template_id(body, %Email{private: %{send_grid_template: %{template_id: template_id}}}) do
    Map.put(body, :template_id, template_id)
  end

  defp put_template_id(body, _), do: body

  defp put_template_substitutions(body, %Email{
         private: %{send_grid_template: %{substitutions: substitutions}}
       }) do
    Map.put(body, :substitutions, substitutions)
  end

  defp put_template_substitutions(body, _), do: body
  
  
  defp put_dynamic_template_data(body, %Email{
         private: %{send_grid_template: %{dynamic_template_data: dynamic_template_data}}
       }) do
    Map.put(body, :dynamic_template_data, dynamic_template_data)
  end

  defp put_dynamic_template_data(body, _), do: body

  defp put_custom_args(body, %Email{private: %{custom_args: custom_args}})
       when is_nil(custom_args) or length(custom_args) == 0,
       do: body

  defp put_custom_args(body, %Email{
         private: %{custom_args: custom_args}
       }) do
    Map.put(body, :custom_args, custom_args)
  end

  defp put_custom_args(body, _), do: body

  defp put_categories(body, %Email{private: %{categories: categories}})
       when is_list(categories) and length(categories) <= 10 do
    body
    |> Map.put(:categories, categories)
  end

  defp put_categories(body, _), do: body

  defp put_attachments(body, %Email{attachments: []}), do: body

  defp put_attachments(body, %Email{attachments: attachments}) do
    transformed =
      attachments
      |> Enum.reverse()
      |> Enum.map(fn attachment ->
        %{
          filename: attachment.filename,
          type: attachment.content_type,
          content: Base.encode64(attachment.data)
        }
      end)

    Map.put(body, :attachments, transformed)
  end

  defp put_addresses(body, _, []), do: body

  defp put_addresses(body, field, addresses),
    do: Map.put(body, field, Enum.map(addresses, &to_address/1))

  defp to_address({nil, address}), do: %{email: address}
  defp to_address({"", address}), do: %{email: address}
  defp to_address({name, address}), do: %{email: address, name: name}

  defp base_uri do
    Application.get_env(:bamboo, :sendgrid_base_uri) || @default_base_uri
  end
end

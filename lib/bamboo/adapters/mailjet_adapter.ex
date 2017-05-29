defmodule Bamboo.MailjetAdapter do
  @moduledoc """
  Sends email using Mailjet's API.

  Use this adapter to send emails through Mailjet's API. Requires that both an API and
  a private API keys are set in the config.

  ## Example config

      # In config/config.exs, or config.prod.exs, etc.
      config :my_app, MyApp.Mailer,
        adapter: Bamboo.MailjetAdapter,
        api_key: "my_api_key",
        api_private_key: "my_private_api_key"

      # Define a Mailer. Maybe in lib/my_app/mailer.ex
      defmodule MyApp.Mailer do
        use Bamboo.Mailer, otp_app: :my_app
      end

   Note: Mailjet provides a "recipients" feature. From the documentation: The recipients
   listed in **Recipients** will each receive a seperate message without showing all the
   other recipients.
   To make use of it in Bamboo, when creating an email, set the "BCC" field only,
   leaving the TO and CC field empty.

   If TO and/or CC field are set, this adapter will generate the TO, CC and BCC
   fields in the "traditional" way.
  """

  @default_base_uri "https://api.mailjet.com/v3"
  @send_message_path "/send"
  @behaviour Bamboo.Adapter

  alias Bamboo.Email

  defmodule ApiError do
    defexception [:message]

    def exception(%{message: message}) do
      %ApiError{message: message}
    end

    def exception(%{params: params, response: response}) do
      message = """
      There was a problem sending the email through the Mailjet API.

      Here is the response:

      #{inspect response, limit: :infinity}

      Here are the params we sent:

      #{inspect params, limit: :infinity}

      """
      %ApiError{message: message}
    end
  end

  def deliver(email, config) do
    api_key = get_key(config,:api_key)
    api_private_key = get_key(config,:api_private_key)
    body = email |> to_mailjet_body |> Poison.encode!
    url = [base_uri, @send_message_path]

    case :hackney.post(url, headers(api_key,api_private_key), body, [:with_body]) do
      {:ok, status, _headers, response} when status > 299 ->
        raise(ApiError, %{params: body, response: response})
      {:ok, status, headers, response} ->
        %{status_code: status, headers: headers, body: response}
      {:error, reason} ->
        raise(ApiError, %{message: inspect(reason)})
    end
  end

  @doc false
  def handle_config(config) do
    cond do
      config[:api_key] in [nil, "", ''] -> raise_key_error(config, :api_key)
      config[:api_private_key] in [nil, "", ''] -> raise_key_error(config, :api_private_key)
      true -> config
    end
  end

  defp get_key(config,key) do
    case Map.get(config, key) do
      nil -> raise_key_error(config,key)
      key -> key
    end
  end

  defp raise_key_error(config, key) do
    raise ArgumentError, """
    There was no #{key} set for the Mailjet adapter.

    * Here are the config options that were passed in:

    #{inspect config}
    """
  end

  defp headers(api_key, api_private_key) do
    [
      {"Content-Type", "application/json"},
      {"Authorization", "Basic " <> Base.encode64("#{api_key}:#{api_private_key}" )}
    ]
  end

  defp to_mailjet_body(%Email{} = email) do
    %{}
    |> put_from(email)
    |> put_subject(email)
    |> put_html_body(email)
    |> put_text_body(email)
    |> put_recipients(email)
  end

  defp put_from(body, %Email{from: address}) when is_binary(address), do: Map.put(body, :fromemail, address)
  defp put_from(body, %Email{from: {name, address}}) when name in [nil, "", ''],
    do: Map.put(body, :fromemail, address)
  defp put_from(body, %Email{from: {name, address}}) do
    body
    |> Map.put(:fromemail, address)
    |> Map.put(:fromname, name)
  end

  defp put_to(body, %Email{to: []}), do: body
  defp put_to(body, %Email{to: to}) do
    Map.put(body, :to, to |> addresses)
  end

  defp put_cc(body, %Email{cc: []}), do: body
  defp put_cc(body, %Email{cc: cc}) do
    Map.put(body, :cc, cc |> addresses)
  end

  defp put_bcc(body, %Email{bcc: []}), do: body
  defp put_bcc(body, %Email{bcc: bcc}) do
    Map.put(body, :bcc, bcc |> addresses)
  end

  defp put_recipients(body, %{to: [], cc: [], bcc: bcc}), do: Map.put(body, :recipients, bcc |> recipients)
  defp put_recipients(body, email) do
    body
    |> put_to(email)
    |> put_cc(email)
    |> put_bcc(email)
  end

  defp put_subject(body, %Email{subject: subject}), do: Map.put(body, :subject, subject)

  defp put_html_body(body, %Email{html_body: nil}), do: body
  defp put_html_body(body, %Email{html_body: html_body}), do: Map.put(body, "html-part", html_body)

  defp put_text_body(body, %Email{text_body: nil}), do: body
  defp put_text_body(body, %Email{text_body: text_body}), do: Map.put(body, "text-part", text_body)

  defp recipients(new_recipients) do
    recipients = []
    Enum.reduce(new_recipients, recipients, fn(recipient, recipients) ->
      recipients ++ case recipient do
        r when is_binary(r) ->
          [%{
            email: r,
          }]
        r when is_tuple(r) ->
          case r |> elem(0) do
            name when name in [nil, '',""] ->
              [%{
                email: r |> elem(1),
              }]
            name ->
              [%{
                name: r |> elem(0),
                email: r |> elem(1),
              }]
          end
      end
    end)
  end

  defp addresses(new_addresses) do
    addresses = []
    Enum.reduce(new_addresses, addresses, fn(address, addresses) ->
      addresses ++ case address do
        a when is_binary(a) ->
          [a]
        a when is_tuple(a) ->
          case a |> elem(0) do
            name when name in [nil, '',""] ->
              [elem(a,1)]
            name ->
              [name <> " <" <> elem(a,1) <> ">"]
          end
      end
    end)
    |> Enum.join(",")
  end

  defp base_uri do
    Application.get_env(:bamboo, :mailjet_base_uri) || @default_base_uri
  end
end

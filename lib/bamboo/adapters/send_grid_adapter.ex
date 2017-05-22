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
  @default_base_uri "https://api.sendgrid.com/api"
  @send_message_path "/mail.send.json"
  @behaviour Bamboo.Adapter

  alias Bamboo.Email
  import Bamboo.ApiError

  def deliver(email, config) do
    api_key = get_key(config)
    body = email |> to_sendgrid_body |> Plug.Conn.Query.encode
    url = [base_uri(), @send_message_path]

    case :hackney.post(url, headers(api_key), body, [:with_body]) do
      {:ok, status, _headers, response} when status > 299 ->
        filtered_params = body |> Plug.Conn.Query.decode |> Map.put("key", "[FILTERED]")
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
      {"Content-Type", "application/x-www-form-urlencoded"},
      {"Authorization", "Bearer #{api_key}"},
    ]
  end

  defp to_sendgrid_body(%Email{} = email) do
    %{}
    |> put_from(email)
    |> put_to(email)
    |> put_reply_to(email)
    |> put_cc(email)
    |> put_bcc(email)
    |> put_subject(email)
    |> put_html_body(email)
    |> put_text_body(email)
    |> maybe_put_x_smtp_api(email)
  end

  defp put_from(body, %Email{from: {"", address}}), do: Map.put(body, :from, address)
  defp put_from(body, %Email{from: {name, address}}) do
    body
    |> Map.put(:from, address)
    |> Map.put(:fromname, name)
  end

  defp put_to(body, %Email{to: to}) do
    {names, addresses} = Enum.unzip(to)
    body
    |> put_addresses(:to, addresses)
    |> put_names(:toname, names)
  end

  defp put_cc(body, %Email{cc: []}), do: body
  defp put_cc(body, %Email{cc: cc}) do
    {names, addresses} = Enum.unzip(cc)
    body
    |> put_addresses(:cc, addresses)
    |> put_names(:ccname, names)
  end

  defp put_bcc(body, %Email{bcc: []}), do: body
  defp put_bcc(body, %Email{bcc: bcc}) do
    {names, addresses} = Enum.unzip(bcc)
    body
    |> put_addresses(:bcc, addresses)
    |> put_names(:bccname, names)
  end

  defp put_subject(body, %Email{subject: subject}), do: Map.put(body, :subject, subject)

  defp put_html_body(body, %Email{html_body: nil}), do: body
  defp put_html_body(body, %Email{html_body: html_body}), do: Map.put(body, :html, html_body)

  defp put_text_body(body, %Email{text_body: nil}), do: body
  defp put_text_body(body, %Email{text_body: text_body}), do: Map.put(body, :text, text_body)


  defp put_reply_to(body, %Email{headers: %{"reply-to" => reply_to}}) do
    Map.put(body, :replyto, reply_to)
  end
  defp put_reply_to(body, _), do: body

  defp maybe_put_x_smtp_api(body, %Email{private: %{"x-smtpapi" => fields}} = email) do
    # SendGrid will error with empty bodies, even while using templates.
    # Sets a default `text_body` and 'html_body' if either are not specified,
    # allowing the consumer to neglect doing so themselves.
    body = if is_nil(email.text_body) do
      put_text_body(body, %Email{email | text_body: " "})
    else
      body
    end

    body = if is_nil(email.html_body) do
      put_html_body(body, %Email{email | html_body: " "})
    else
      body
    end

    body = if is_nil(email.subject) do
      put_subject(body, %Email{email | subject: " "})
    else
      body
    end

    Map.put(body, "x-smtpapi", Poison.encode!(fields))
  end
  defp maybe_put_x_smtp_api(body, _), do: body

  defp put_addresses(body, field, addresses), do: Map.put(body, field, addresses)
  defp put_names(body, field, names) do
    if list_empty?(names) do
      body
    else
      Map.put(body, field, names)
    end
  end

  defp list_empty?([]), do: true
  defp list_empty?(list) do
    Enum.all?(list, fn(el) -> el == "" || el == nil end)
  end

  defp base_uri do
    Application.get_env(:bamboo, :sendgrid_base_uri) || @default_base_uri
  end
end

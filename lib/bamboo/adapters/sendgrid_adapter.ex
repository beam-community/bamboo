defmodule Bamboo.SendgridAdapter do
  @moduledoc """
  Sends email using SendGrid's JSON API.

  Use this adapter to send emails through SendGrid's API. Requires that an API
  key is set in the config.

  ## Example config

      # In config/config.exs, or config.prod.exs, etc.
      config :my_app, MyApp.Mailer,
        adapter: Bamboo.SendgridAdapter,
        api_key: "my_api_key"

      # Define a Mailer. Maybe in lib/my_app/mailer.ex
      defmodule MyApp.Mailer do
        use Bamboo.Mailer, otp_app: :my_app
      end
  """

  @default_base_uri "https://api.sendgrid.com/api"
  @send_message_path "/mail.send.json"
  @behaviour Bamboo.Adapter

  alias Bamboo.Email

  defmodule ApiError do
    defexception [:message]

    def exception(%{message: message}) do
      %ApiError{message: message}
    end

    def exception(%{params: params, response: response}) do
      filtered_params = params |> Plug.Conn.Query.decode |> Map.put("key", "[FILTERED]")

      message = """
      There was a problem sending the email through the SendGrid API.

      Here is the response:

      #{inspect response, limit: :infinity}

      Here are the params we sent:

      #{inspect filtered_params, limit: :infinity}

      If you are deploying to Heroku and using ENV variables to handle your API key,
      you will need to explicitly export the variables so they are available at compile time.
      Add the following configuration to your elixir_buildpack.config:

      config_vars_to_export=(
        DATABASE_URL
        SENDGRID_API_KEY
      )
      """
      %ApiError{message: message}
    end
  end

  def deliver(email, config) do
    api_key = get_key(config)
    body = email |> to_sendgrid_body |> Plug.Conn.Query.encode
    url = [base_uri, @send_message_path]

    case :hackney.post(url, headers(api_key), body, [:with_body]) do
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
    |> put_cc(email)
    |> put_bcc(email)
    |> put_subject(email)
    |> put_html_body(email)
    |> put_text_body(email)
    |> put_x_smtp_api(email)
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

  defp put_x_smtp_api(body, %Email{private: %{"x-smtpapi" => fields}} = email) do
    # SendGrid will error with empty bodies, even while using templates.
    # Sets a default `text_body` if one is not specified, allowing the consumer
    # to negelect doing so themselves.
    case {email.text_body, email.html_body} do
      {nil, nil} -> put_text_body(body, %Email{email | text_body: " "})
      _ -> body
    end |> Map.put("x-smtpapi", Poison.encode!(fields))
  end
  defp put_x_smtp_api(body, _), do: body

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

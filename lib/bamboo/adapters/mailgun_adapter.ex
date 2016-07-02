defmodule Bamboo.MailgunAdapter do
  @moduledoc """
  Sends email using Mailgun's API.

  Use this adapter to send emails through Mailgun's API. Requires that an API
  key and a domain are set in the config.

  ## Example config

      # In config/config.exs, or config.prod.exs, etc.
      config :my_app, MyApp.Mailer,
        adapter: Bamboo.MailgunAdapter,
        api_key: "my_api_key",
        domain: "your.domain"

      # Define a Mailer. Maybe in lib/my_app/mailer.ex
      defmodule MyApp.Mailer do
        use Bamboo.Mailer, otp_app: :my_app
      end
  """

  @default_base_uri "https://api.mailgun.net/v3/"
  @base_uri Application.get_env(:bamboo, :mailgun_base_uri, @default_base_uri)
  @behaviour Bamboo.Adapter

  alias Bamboo.Email

  defmodule ApiError do
    defexception [:message]

    def exception(%{params: params, response: response}) do
      message = """
      There was a problem sending the email through the Mailgun API.

      Here is the response:

      #{inspect response, limit: :infinity}


      Here are the params we sent:

      #{inspect params, limit: :infinity}
      """
      %ApiError{message: message}
    end
  end

  def deliver(email, config) do
    body = email |> to_mailgun_body |> Plug.Conn.Query.encode

    case HTTPoison.post!(full_uri(config), body, headers(config)) do
      %{status_code: status} = response when status > 299 ->
        raise(ApiError, %{params: body, response: response})
      response -> response
    end
  end

  @doc false
  def handle_config(config) do
    for setting <- [:api_key, :domain] do
      if config[setting] in [nil, ""] do
        raise_missing_setting_error(config, setting)
      end
    end
    config
  end

  defp raise_missing_setting_error(config, setting) do
    raise ArgumentError, """
    There was no #{setting} set for the Mailgun adapter.

    * Here are the config options that were passed in:

    #{inspect config}
    """
  end

  defp headers(config) do
    [
      {"Content-Type", "application/x-www-form-urlencoded"},
      {"Authorization", "Basic #{auth_token(config)}"},
    ]
  end

  defp auth_token(config) do
    Base.encode64("api:" <> config.api_key)
  end

  @mailgun_message_fields ~w(from to cc bcc subject text html)a

  defp to_mailgun_body(%Email{} = email) do
    email
    |> Map.from_struct
    |> combine_name_and_email
    |> put_html_body(email)
    |> put_text_body(email)
    |> Map.take(@mailgun_message_fields)
    |> remove_empty_fields
  end

  defp combine_name_and_email(map) when is_map(map) do
    Enum.reduce([:from, :to, :cc, :bcc], map, fn key, acc ->
      Map.put(acc, key, combine_name_and_email(map[key]))
    end)
  end

  defp combine_name_and_email(list) when is_list(list) do
    Enum.map(list, &combine_name_and_email/1)
  end

  defp combine_name_and_email(tuple) when is_tuple(tuple) do
    case tuple do
      {nil, email} -> email
      {name, email} -> "#{name} <#{email}>"
    end
  end

  defp remove_empty_fields(params) do
    Enum.reject(params, fn {_k, v} -> v in [nil, "", []] end)
  end

  defp put_html_body(body, %Email{html_body: html_body}), do: Map.put(body, :html, html_body)

  defp put_text_body(body, %Email{text_body: text_body}), do: Map.put(body, :text, text_body)

  defp full_uri(config) do
    @base_uri <> config.domain <> "/messages"
  end
end

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

  @service_name "Mailgun"
  @base_uri "https://api.mailgun.net/v3"
  @behaviour Bamboo.Adapter

  alias Bamboo.{Email, Attachment}
  import Bamboo.ApiError

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

    #{inspect(config)}
    """
  end

  def deliver(email, config) do
    body = to_mailgun_body(email)

    case :hackney.post(full_uri(config), headers(email, config), body, [:with_body]) do
      {:ok, status, _headers, response} when status > 299 ->
        raise_api_error(@service_name, response, body)

      {:ok, status, headers, response} ->
        %{status_code: status, headers: headers, body: response}

      {:error, reason} ->
        raise_api_error(inspect(reason))
    end
  end

  @doc false
  def supports_attachments?, do: true

  defp full_uri(config) do
    Application.get_env(:bamboo, :mailgun_base_uri, @base_uri) <>
      "/" <> config.domain <> "/messages"
  end

  defp headers(%Email{} = email, config) do
    [{"Content-Type", content_type(email)}, {"Authorization", "Basic #{auth_token(config)}"}]
  end

  defp auth_token(config), do: Base.encode64("api:" <> config.api_key)

  defp content_type(%{attachments: []}), do: "application/x-www-form-urlencoded"
  defp content_type(%{}), do: "multipart/form-data"

  defp to_mailgun_body(email) do
    []
    |> put_from(email)
    |> put_to(email)
    |> put_subject(email)
    |> put_html(email)
    |> put_text(email)
    |> put_cc(email)
    |> put_bcc(email)
    |> put_headers(email)
    |> put_custom_vars(email)
    |> filter_non_empty_mailgun_fields
    |> encode_body(email)
  end

  defp put_from(body, %Email{from: from}), do: [{:from, prepare_recipient(from)} | body]

  defp put_to(body, %Email{to: to}), do: [{:to, prepare_recipients(to)} | body]

  defp put_cc(body, %Email{cc: []}), do: body
  defp put_cc(body, %Email{cc: cc}), do: [{:cc, prepare_recipients(cc)} | body]

  defp put_bcc(body, %Email{bcc: []}), do: body
  defp put_bcc(body, %Email{bcc: bcc}), do: [{:bcc, prepare_recipients(bcc)} | body]

  defp prepare_recipients(recipients) do
    recipients
    |> Enum.map(&prepare_recipient(&1))
    |> Enum.join(",")
  end

  defp prepare_recipient({nil, address}), do: address
  defp prepare_recipient({"", address}), do: address
  defp prepare_recipient({name, address}), do: "#{name} <#{address}>"

  defp put_subject(body, %Email{subject: subject}), do: [{:subject, subject} | body]

  defp put_text(body, %Email{text_body: nil}), do: body
  defp put_text(body, %Email{text_body: text_body}), do: [{:text, text_body} | body]

  defp put_html(body, %Email{html_body: nil}), do: body
  defp put_html(body, %Email{html_body: html_body}), do: [{:html, html_body} | body]

  defp put_headers(body, %Email{headers: headers}) do
    Enum.reduce(headers, body, fn {key, value}, acc ->
      [{"h:#{key}", value} | acc]
    end)
  end

  defp put_custom_vars(body, %Email{private: private}) do
    custom_vars = Map.get(private, :mailgun_custom_vars, %{})

    Enum.reduce(custom_vars, body, fn {key, value}, acc ->
      [{"v:#{key}", value} | acc]
    end)
  end

  defp put_attachments(body, []), do: body

  defp put_attachments(body, attachments) do
    attachments
    |> Enum.reverse()
    |> Enum.map(&prepare_file(&1))
    |> Enum.concat(body)
  end

  defp prepare_file(%Attachment{} = attachment) do
    {"", attachment.data,
     {"form-data", [{"name", ~s/"attachment"/}, {"filename", ~s/"#{attachment.filename}"/}]}, []}
  end

  @mailgun_message_fields ~w(from to cc bcc subject text html)a

  def filter_non_empty_mailgun_fields(body) do
    Enum.filter(body, fn {key, value} ->
      # Key is a well known mailgun field (including header and custom var field) and its value is not empty
      (key in @mailgun_message_fields || String.starts_with?(key, ["h:", "v:"])) &&
        !(value in [nil, "", []])
    end)
  end

  defp encode_body(body, %Email{attachments: attachments}) do
    {
      :multipart,
      body
      |> Enum.map(fn {k, v} -> {to_string(k), to_string(v)} end)
      # Append the attachement parts
      |> put_attachments(attachments)
    }
  end

  defp encode_body(body_without_attachments, _),
    do: Plug.Conn.Query.encode(body_without_attachments)
end

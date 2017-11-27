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
  @api_endpoint "/messages"
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

    #{inspect config}
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
    Application.get_env(:bamboo, :mailgun_base_uri, @base_uri)
    <> "/" <> config.domain <> "/messages"
  end

  defp headers(%Email{} = email, config) do
    [{"Content-Type", content_type(email)},
      {"Authorization", "Basic #{auth_token(config)}"}]
  end

  defp auth_token(config), do: Base.encode64("api:" <> config.api_key)

  defp content_type(%{attachments: []}), do: "application/x-www-form-urlencoded"
  defp content_type(%{}), do: "multipart/form-data"

  defp to_mailgun_body(email) do
    %{}
    |> put_from(email)
    |> put_to(email)
    |> put_subject(email)
    |> put_html(email)
    |> put_text(email)
    |> put_cc(email)
    |> put_bcc(email)
    |> put_reply_to(email)
    |> put_attachments(email)
    |> put_headers(email)
    |> encode_body
  end

  defp put_headers(body, %Email{headers: headers}) do
    Enum.reduce(headers, body, fn({key, value}, acc) ->
      Map.put(acc, :"h:#{key}", value)
    end)
  end

  defp put_attachments(body, %{attachments: []}), do: body
  defp put_attachments(body, %{attachments: attachments}) do
    attachment_data =
      attachments
      |> Enum.reverse
      |> Enum.map(&prepare_file(&1))

    Map.put(body, :attachments, attachment_data)
  end

  defp prepare_file(%Attachment{path: nil} = attachment) do
    {"", attachment.data,
     {"form-data",
      [{"name", ~s/"attachment"/},
       {"filename", ~s/"#{attachment.filename}"/}]},
     []}
  end
  defp prepare_file(%Attachment{} = attachment) do
    {"", attachment.data,
     {"form-data",
      [{"name", ~s/"attachment"/},
       {"filename", ~s/"#{attachment.filename}"/}]},
     []}
  end

  defp put_from(body, %{from: from}), do: Map.put(body, :from, prepare_recipient(from))

  defp put_to(body, %{to: to}), do: Map.put(body, :to, prepare_recipients(to))

  defp put_reply_to(body, %Email{headers: %{"reply-to" => nil}}), do: body
  defp put_reply_to(body, %Email{headers: %{"reply-to" => address}}), do: Map.put(body, "h:Reply-To", address)
  defp put_reply_to(body, %Email{headers: _headers}), do: body

  defp put_cc(body, %{cc: []}), do: body
  defp put_cc(body, %{cc: cc}), do: Map.put(body, :cc, prepare_recipients(cc))

  defp put_bcc(body, %{bcc: []}), do: body
  defp put_bcc(body, %{bcc: bcc}), do: Map.put(body, :bcc, prepare_recipients(bcc))

  defp prepare_recipients(recipients) do
    recipients
    |> Enum.map(&prepare_recipient(&1))
    |> Enum.join(",")
  end

  defp prepare_recipient({nil, address}), do: address
  defp prepare_recipient({"", address}), do: address
  defp prepare_recipient({name, address}), do: "#{name} <#{address}>"

  defp put_subject(body, %{subject: subject}), do: Map.put(body, :subject, subject)

  defp put_text(body, %{text_body: nil}), do: body
  defp put_text(body, %{text_body: text_body}), do: Map.put(body, :text, text_body)

  defp put_html(body, %{html_body: nil}), do: body
  defp put_html(body, %{html_body: html_body}), do: Map.put(body, :html, html_body)

  defp encode_body(%{attachments: attachments} = params) do
    {:multipart,
     params
     |> Map.drop([:attachments])
     |> Enum.map(fn {k, v} -> {to_string(k), v} end)
     |> Kernel.++(attachments)}
  end
  defp encode_body(no_attachments), do: Plug.Conn.Query.encode(no_attachments)
end

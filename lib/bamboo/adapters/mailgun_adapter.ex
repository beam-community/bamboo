defmodule Bamboo.MailgunAdapter do
  @moduledoc """
  Sends email using Mailgun's API.

  Use this adapter to send emails through Mailgun's API. Requires that an API
  key and a domain are set in the config.

  See `Bamboo.MailgunHelper` for extra functions that can be used by Bamboo.MailgunAdapter (tagging, merge vars, etc.)

  ## Example config

      # In config/config.exs, or config.prod.exs, etc.
      config :my_app, MyApp.Mailer,
        adapter: Bamboo.MailgunAdapter,
        api_key: "my_api_key" # or {:system, "MAILGUN_API_KEY"},
        domain: "your.domain" # or {:system, "MAILGUN_DOMAIN"},
        hackney_opts: [
          recv_timeout: :timer.minutes(1)
        ]

      # Define a Mailer. Maybe in lib/my_app/mailer.ex
      defmodule MyApp.Mailer do
        use Bamboo.Mailer, otp_app: :my_app
      end

  ## API base URI configuration

  Mailgun makes a difference in the API base URL between sender
  domains from within the EU and outside.

  By default, the base URL is set to `https://api.mailgun.net/v3`.
  To override this globally, you can use the Application environment:

      Application.put_env(:bamboo, :mailgun_base_uri, "https://api.eu.mailgun.net/v3")

  However, for advanced configurations (for instance, for multi-tenant
  setups where you pass in the adapter config when an email is sent),
  you might want to specify this on the adapter level:

      config :my_app, MyApp.Mailer,
        adapter: Bamboo.MailgunAdapter,
        api_key: "my_api_key",
        domain: "your.domain",
        base_uri: "https://api.eu.mailgun.net/v3"

  """

  @service_name "Mailgun"
  @default_base_uri "https://api.mailgun.net/v3"
  @behaviour Bamboo.Adapter

  alias Bamboo.{Email, Attachment, AdapterHelper}
  import Bamboo.ApiError

  @doc false
  def handle_config(config) do
    config
    |> Map.put(:api_key, get_setting(config, :api_key))
    |> Map.put(:domain, get_setting(config, :domain))
    |> Map.put_new(:base_uri, base_uri())
  end

  defp base_uri() do
    Application.get_env(:bamboo, :mailgun_base_uri, @default_base_uri)
  end

  defp get_setting(config, key) do
    config[key]
    |> case do
      {:system, var} ->
        System.get_env(var)

      value ->
        value
    end
    |> case do
      value when value in [nil, ""] ->
        raise_missing_setting_error(config, key)

      value ->
        value
    end
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
    config = handle_config(config)

    case :hackney.post(
           full_uri(config),
           headers(email, config),
           body,
           AdapterHelper.hackney_opts(config)
         ) do
      {:ok, status, _headers, response} when status > 299 ->
        body = decode_body(body)
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
    config.base_uri <> "/" <> config.domain <> "/messages"
  end

  defp headers(%Email{} = email, config) do
    [{"Content-Type", content_type(email)}, {"Authorization", "Basic #{auth_token(config)}"}]
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
    |> put_tag(email)
    |> put_deliverytime(email)
    |> put_template(email)
    |> put_template_version(email)
    |> put_template_text(email)
    |> put_custom_vars(email)
    |> put_recipient_variables(email)
    |> filter_non_empty_mailgun_fields
    |> encode_body
  end

  defp put_from(body, %Email{from: from}), do: Map.put(body, :from, prepare_recipient(from))

  defp put_to(body, %Email{to: to}), do: Map.put(body, :to, prepare_recipients(to))

  defp put_reply_to(body, %Email{headers: %{"reply-to" => nil}}), do: body

  defp put_reply_to(body, %Email{headers: %{"reply-to" => address}}),
    do: Map.put(body, :"h:Reply-To", address)

  defp put_reply_to(body, %Email{headers: _headers}), do: body

  defp put_cc(body, %Email{cc: []}), do: body
  defp put_cc(body, %Email{cc: cc}), do: Map.put(body, :cc, prepare_recipients(cc))

  defp put_bcc(body, %Email{bcc: []}), do: body
  defp put_bcc(body, %Email{bcc: bcc}), do: Map.put(body, :bcc, prepare_recipients(bcc))

  defp prepare_recipients(recipients) do
    recipients
    |> Enum.map(&prepare_recipient(&1))
    |> Enum.join(",")
  end

  defp prepare_recipient({nil, address}), do: address
  defp prepare_recipient({"", address}), do: address
  defp prepare_recipient({name, address}), do: "#{name} <#{address}>"

  defp put_subject(body, %Email{subject: subject}), do: Map.put(body, :subject, subject)

  defp put_text(body, %Email{text_body: nil}), do: body
  defp put_text(body, %Email{text_body: text_body}), do: Map.put(body, :text, text_body)

  defp put_html(body, %Email{html_body: nil}), do: body
  defp put_html(body, %Email{html_body: html_body}), do: Map.put(body, :html, html_body)

  defp put_headers(body, %Email{headers: headers}) do
    Enum.reduce(headers, body, fn {key, value}, acc ->
      Map.put(acc, :"h:#{key}", value)
    end)
  end

  defp put_tag(body, %Email{private: %{:"o:tag" => tag}}), do: Map.put(body, :"o:tag", tag)
  defp put_tag(body, %Email{}), do: body

  defp put_deliverytime(body, %Email{private: %{:"o:deliverytime" => deliverytime}}),
    do: Map.put(body, :"o:deliverytime", deliverytime)

  defp put_deliverytime(body, %Email{}), do: body

  defp put_template(body, %Email{private: %{template: template}}),
    do: Map.put(body, :template, template)

  defp put_template(body, %Email{}), do: body

  defp put_template_version(body, %Email{private: %{:"t:version" => template_version}}) do
    Map.put(body, :"t:version", template_version)
  end

  defp put_template_version(body, %Email{}), do: body

  defp put_template_text(body, %Email{private: %{:"t:text" => true}}) do
    Map.put(body, :"t:text", "yes")
  end

  defp put_template_text(body, %Email{}), do: body

  defp put_custom_vars(body, %Email{private: private}) do
    custom_vars = Map.get(private, :mailgun_custom_vars, %{})

    Enum.reduce(custom_vars, body, fn {key, value}, acc ->
      Map.put(acc, :"v:#{key}", value)
    end)
  end

  defp put_recipient_variables(body, %Email{private: private}) do
    recipient_variables = Map.get(private, :mailgun_recipient_variables)

    if recipient_variables do
      Map.put(body, :"recipient-variables", recipient_variables)
    else
      body
    end
  end

  defp put_attachments(body, %Email{attachments: []}), do: body

  defp put_attachments(body, %Email{attachments: attachments}) do
    attachment_data =
      attachments
      |> Enum.reverse()
      |> Enum.map(&prepare_file(&1))

    Map.put(body, :attachments, attachment_data)
  end

  defp prepare_file(%Attachment{} = attachment) do
    {"", attachment.data,
     {"form-data", [{"name", ~s/"attachment"/}, {"filename", ~s/"#{attachment.filename}"/}]}, []}
  end

  @mailgun_message_fields ~w(from to cc bcc subject text html template recipient-variables)a
  @internal_fields ~w(attachments)a

  def filter_non_empty_mailgun_fields(body) do
    Enum.filter(body, fn {key, value} ->
      # Key is a well known mailgun field (including header and custom var field) and its value is not empty
      (key in @mailgun_message_fields || key in @internal_fields ||
         String.starts_with?(Atom.to_string(key), ["h:", "v:", "o:", "t:"])) &&
        !(value in [nil, "", []])
    end)
    |> Enum.into(%{})
  end

  defp encode_body(%{attachments: attachments} = body) do
    {
      :multipart,
      # Drop the remaining non-Mailgun fields
      # Append the attachment parts
      body
      |> Map.drop(@internal_fields)
      |> Enum.map(fn {k, v} -> {to_string(k), to_string(v)} end)
      |> Kernel.++(attachments)
    }
  end

  defp encode_body(body_without_attachments), do: Plug.Conn.Query.encode(body_without_attachments)

  defp decode_body({:multipart, _} = multipart_body), do: multipart_body

  defp decode_body(body_without_attachments) when is_binary(body_without_attachments),
    do: Plug.Conn.Query.decode(body_without_attachments)
end

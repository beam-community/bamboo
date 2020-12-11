defmodule Bamboo.SendGridAdapter do
  @moduledoc """
  Sends email using SendGrid's JSON API.

  Use this adapter to send emails through SendGrid's API. Requires that an API
  key is set in the config.

  If you would like to add a replyto header to your email, then simply pass it in
  using the header property or put_header function like so:

      put_header("reply-to", "foo@bar.com")

  To set arbitrary email headers, set them in the `headers` property of the [Bamboo.Email](Bamboo.Email) struct.
  Note that some header names are reserved for use by Sendgrid. See
  [here](https://sendgrid.com/docs/API_Reference/Web_API_v3/Mail/index.html) for full list.

  ## Example config

      # In config/config.exs, or config.prod.exs, etc.
      config :my_app, MyApp.Mailer,
        adapter: Bamboo.SendGridAdapter,
        api_key: "my_api_key",
          # or {:system, "SENDGRID_API_KEY"},
          # or {ModuleName, :method_name, []}
        hackney_opts: [
          recv_timeout: :timer.minutes(1)
        ]

      # To enable sandbox mode (e.g. in development or staging environments),
      # in config/dev.exs or config/prod.exs etc
      config :my_app, MyApp.Mailer, sandbox: true

      # Define a Mailer. Maybe in lib/my_app/mailer.ex
      defmodule MyApp.Mailer do
        use Bamboo.Mailer, otp_app: :my_app
      end

  """

  @service_name "SendGrid"
  @default_base_uri "https://api.sendgrid.com/v3/"
  @send_message_path "/mail/send"
  @behaviour Bamboo.Adapter

  alias Bamboo.{Email, AdapterHelper, Formatter}
  import Bamboo.ApiError

  def deliver(email, config) do
    api_key = get_key(config)
    body = email |> to_sendgrid_body(config) |> Bamboo.json_library().encode!()
    url = [base_uri(), @send_message_path]

    case :hackney.post(url, headers(api_key), body, AdapterHelper.hackney_opts(config)) do
      {:ok, status, _headers, response} when status > 299 ->
        filtered_params = body |> Bamboo.json_library().decode!() |> Map.put("key", "[FILTERED]")
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
        {module_name, method_name, args} -> apply(module_name, method_name, args)
        fun when is_function(fun) -> fun.()
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
      {"Accept", "application/json"},
      {"Content-Type", "application/json"},
      {"Authorization", "Bearer #{api_key}"}
    ]
  end

  defp to_sendgrid_body(%Email{} = email, config) do
    %{}
    |> put_from(email)
    |> put_personalizations(email)
    |> put_reply_to(email)
    |> put_headers(email)
    |> put_subject(email)
    |> put_content(email)
    |> put_template_id(email)
    |> put_attachments(email)
    |> put_categories(email)
    |> put_send_at(email)
    |> put_settings(config)
    |> put_asm_group_id(email)
    |> put_bypass_list_management(email)
    |> put_google_analytics(email)
    |> put_ip_pool_name(email)
  end

  defp put_from(body, %Email{from: from}) do
    Map.put(body, :from, to_address(from))
  end

  defp put_personalizations(body, email) do
    Map.put(body, :personalizations, personalizations(email))
  end

  defp personalizations(email) do
    base_personalization =
      %{}
      |> put_to(email)
      |> put_cc(email)
      |> put_bcc(email)
      |> put_custom_args(email)
      |> put_template_substitutions(email)
      |> put_dynamic_template_data(email)
      |> put_send_at(email)

    additional_personalizations =
      email.private
      |> Map.get(:additional_personalizations, [])
      |> Enum.map(&build_personalization/1)

    if base_personalization == %{} do
      additional_personalizations
    else
      [base_personalization] ++ additional_personalizations
    end
  end

  defp build_personalization(personalization = %{to: to}) do
    %{to: cast_addresses(to, :to)}
    |> map_put_if(personalization, :cc, &cast_addresses(&1, :cc))
    |> map_put_if(personalization, :bcc, &cast_addresses(&1, :bcc))
    |> map_put_if(personalization, :custom_args)
    |> map_put_if(personalization, :substitutions)
    |> map_put_if(personalization, :subject)
    |> map_put_if(personalization, :headers)
    |> map_put_if(personalization, :send_at, &cast_time/1)
  end

  defp build_personalization(_personalization) do
    raise "Each personalization requires a 'to' field"
  end

  defp map_put_if(map_out, map_in, key, mapper \\ & &1) do
    case Map.fetch(map_in, key) do
      {:ok, value} -> Map.put(map_out, key, mapper.(value))
      :error -> map_out
    end
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

  defp put_reply_to(body, %Email{headers: %{"reply-to" => {name, email}}}) do
    Map.put(body, :reply_to, %{email: email, name: name})
  end

  defp put_reply_to(body, %Email{headers: %{"reply-to" => reply_to}}) do
    Map.put(body, :reply_to, %{email: reply_to})
  end

  defp put_reply_to(body, %Email{headers: %{"Reply-To" => {name, email}}}) do
    Map.put(body, :reply_to, %{email: email, name: name})
  end

  defp put_reply_to(body, %Email{headers: %{"Reply-To" => reply_to}}) do
    Map.put(body, :reply_to, %{email: reply_to})
  end

  defp put_reply_to(body, _), do: body

  defp put_headers(body, %Email{headers: headers}) when is_map(headers) do
    headers_without_tuple_values =
      headers
      |> Map.delete("reply-to")
      |> Map.delete("Reply-To")

    Map.put(body, :headers, headers_without_tuple_values)
  end

  defp put_headers(body, _), do: body

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

  defp put_settings(body, %{sandbox: true}),
    do: Map.put(body, :mail_settings, %{sandbox_mode: %{enable: true}})

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

  defp put_send_at(body, %Email{private: %{sendgrid_send_at: send_at_timestamp}}) do
    body
    |> Map.put(:send_at, send_at_timestamp)
  end

  defp put_send_at(body, _), do: body

  defp put_asm_group_id(body, %Email{private: %{asm_group_id: asm_group_id}})
       when is_integer(asm_group_id) do
    body
    |> Map.put(:asm, %{group_id: asm_group_id})
  end

  defp put_asm_group_id(body, _), do: body

  defp put_bypass_list_management(body, %Email{private: %{bypass_list_management: enabled}})
       when is_boolean(enabled) do
    mail_settings =
      body
      |> Map.get(:mail_settings, %{})
      |> Map.put(:bypass_list_management, %{enable: enabled})

    body
    |> Map.put(:mail_settings, mail_settings)
  end

  defp put_bypass_list_management(body, _), do: body

  defp put_google_analytics(body, %Email{
         private: %{google_analytics_enabled: enabled, google_analytics_utm_params: utm_params}
       }) do
    ganalytics = %{enable: enabled} |> Map.merge(utm_params)

    tracking_settings =
      body
      |> Map.get(:tracking_settings, %{})
      |> Map.put(:ganalytics, ganalytics)

    body
    |> Map.put(:tracking_settings, tracking_settings)
  end

  defp put_google_analytics(body, _), do: body

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

  defp cast_time(%DateTime{} = date_time), do: DateTime.to_unix(date_time)
  defp cast_time(unix_timestamp) when is_integer(unix_timestamp), do: unix_timestamp

  defp cast_time(_other) do
    raise "expected 'send_at' time parameter to be a DateTime or unix timestamp"
  end

  defp cast_addresses(addresses, type) when is_list(addresses) do
    Enum.map(addresses, &cast_address(&1, type))
  end

  defp cast_addresses(address, type), do: cast_addresses([address], type)

  # SendGrid wants emails as a map
  defp cast_address(%_{} = address, type) do
    case Formatter.impl_for(address) do
      nil -> cast_address_as_map(address)
      _ -> cast_address_with_formatter(address, type)
    end
  end

  defp cast_address(address, _type) when is_map(address) do
    cast_address_as_map(address)
  end

  defp cast_address(address, type) do
    cast_address_with_formatter(address, type)
  end

  defp cast_address_as_map(address) do
    case {Map.get(address, :name, Map.get(address, "name")),
          Map.get(address, :email, Map.get(address, "email"))} do
      {_name, nil} ->
        raise "Must specify at least an 'email' field in map #{inspect(address)}"

      {nil, address} ->
        %{email: address}

      {name, address} ->
        %{email: address, name: name}
    end
  end

  defp cast_address_with_formatter(address, type) do
    {name, address} = Formatter.format_email_address(address, type)

    case {name, address} do
      {nil, address} -> %{email: address}
      {name, address} -> %{email: address, name: name}
    end
  end

  defp put_ip_pool_name(body, %Email{private: %{ip_pool_name: ip_pool_name}}),
    do: Map.put(body, :ip_pool_name, ip_pool_name)

  defp put_ip_pool_name(body, _), do: body
end

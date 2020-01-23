defmodule Bamboo.MandrillAdapter do
  @moduledoc """
  Sends email using Mandrill's JSON API.

  Use this adapter to send emails through Mandrill's API. Requires that an API
  key is set in the config. See `Bamboo.MandrillHelper` for extra functions that
  can be used by `Bamboo.MandrillAdapter` (tagging, merge vars, etc.)

  ## Example config

      # In config/config.exs, or config/prod.exs, etc.
      config :my_app, MyApp.Mailer,
        adapter: Bamboo.MandrillAdapter,
        api_key: "my_api_key",
        hackney_opts: [
          recv_timeout: :timer.minutes(1)
        ]

      # Define a Mailer. Maybe in lib/my_app/mailer.ex
      defmodule MyApp.Mailer do
        use Bamboo.Mailer, otp_app: :my_app
      end
  """

  @service_name "Mandrill"
  @default_base_uri "https://mandrillapp.com"
  @send_message_path "api/1.0/messages/send.json"
  @send_message_template_path "api/1.0/messages/send-template.json"
  @behaviour Bamboo.Adapter

  alias Bamboo.AdapterHelper
  import Bamboo.ApiError

  def deliver(email, config) do
    api_key = get_key(config)
    params = email |> convert_to_mandrill_params(api_key) |> Bamboo.json_library().encode!()
    uri = [base_uri(), "/", api_path(email)]

    case :hackney.post(uri, headers(), params, AdapterHelper.hackney_opts(config)) do
      {:ok, status, _headers, response} when status > 299 ->
        filtered_params =
          params |> Bamboo.json_library().decode!() |> Map.put("key", "[FILTERED]")

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
    There was no API key set for the Mandrill adapter.

    * Here are the config options that were passed in:

    #{inspect(config)}
    """
  end

  defp convert_to_mandrill_params(email, api_key) do
    %{key: api_key, message: message_params(email)}
    |> maybe_put_template_params(email)
  end

  defp maybe_put_template_params(params, %{
         private: %{template_name: template_name, template_content: template_content}
       }) do
    params
    |> Map.put(:template_name, template_name)
    |> Map.put(:template_content, template_content)
  end

  defp maybe_put_template_params(params, _), do: params

  defp message_params(email) do
    %{
      from_name: email.from |> elem(0),
      from_email: email.from |> elem(1),
      to: recipients(email),
      subject: email.subject,
      text: email.text_body,
      html: email.html_body,
      headers: email.headers,
      attachments: attachments(email)
    }
    |> add_message_params(email)
  end

  defp add_message_params(mandrill_message, %{private: %{message_params: message_params}}) do
    Enum.reduce(message_params, mandrill_message, fn {key, value}, mandrill_message ->
      Map.put(mandrill_message, key, value)
    end)
  end

  defp add_message_params(mandrill_message, _), do: mandrill_message

  defp attachments(%{attachments: attachments}) do
    attachments
    |> Enum.reverse()
    |> Enum.map(fn attachment ->
      %{
        name: attachment.filename,
        type: attachment.content_type,
        content: Base.encode64(attachment.data)
      }
    end)
  end

  defp recipients(email) do
    []
    |> add_recipients(email.to, type: "to")
    |> add_recipients(email.cc, type: "cc")
    |> add_recipients(email.bcc, type: "bcc")
  end

  defp add_recipients(recipients, new_recipients, type: recipient_type) do
    Enum.reduce(new_recipients, recipients, fn recipient, recipients ->
      recipients ++
        [
          %{
            name: recipient |> elem(0),
            email: recipient |> elem(1),
            type: recipient_type
          }
        ]
    end)
  end

  defp api_path(%{private: %{template_name: _}}), do: @send_message_template_path
  defp api_path(_), do: @send_message_path

  defp headers do
    [{"content-type", "application/json"}]
  end

  defp base_uri do
    Application.get_env(:bamboo, :mandrill_base_uri) || @default_base_uri
  end
end

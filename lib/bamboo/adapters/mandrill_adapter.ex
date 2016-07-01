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
        api_key: "my_api_key"

      # Define a Mailer. Maybe in lib/my_app/mailer.ex
      defmodule MyApp.Mailer do
        use Bamboo.Mailer, otp_app: :my_app
      end
  """

  @default_base_uri "https://mandrillapp.com/"
  @send_message_path "api/1.0/messages/send.json"
  @send_message_template_path "api/1.0/messages/send-template.json"
  @behaviour Bamboo.Adapter

  defmodule ApiError do
    defexception [:message]

    def exception(%{params: params, response: response}) do
      filtered_params = params |> Poison.decode! |> Map.put("key", "[FILTERED]")

      message = """
      There was a problem sending the email through the Mandrill API.

      Here is the response:

      #{inspect response, limit: :infinity}

      Here are the params we sent:

      #{inspect filtered_params, limit: :infinity}

      If you are deploying to Heroku and using ENV variables to handle your API key,
      you will need to explicitly export the variables so they are available at compile time.
      Add the following configuration to your elixir_buildpack.config:

      config_vars_to_export=(
        DATABASE_URL
        MANDRILL_API_KEY
      )
      """
      %ApiError{message: message}
    end
  end

  def deliver(email, config) do
    api_key = get_key(config)
    params = email |> convert_to_mandrill_params(api_key) |> Poison.encode!
    case request!(api_path(email), params) do
      %{status_code: status} = response when status > 299 ->
        raise(ApiError, %{params: params, response: response})
      response -> response
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
    There was no API key set for the Mandrill adapter.

    * Here are the config options that were passed in:

    #{inspect config}
    """
  end

  defp convert_to_mandrill_params(email, api_key) do
    %{key: api_key, message: message_params(email)}
    |> maybe_put_template_params(email)
  end

  defp maybe_put_template_params(params, %{private: %{template_name: template_name, template_content: template_content}}) do
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
      headers: email.headers
    }
    |> add_message_params(email)
  end

  defp add_message_params(mandrill_message, %{private: %{message_params: message_params}}) do
    Enum.reduce(message_params, mandrill_message, fn({key, value}, mandrill_message) ->
      Map.put(mandrill_message, key, value)
    end)
  end
  defp add_message_params(mandrill_message, _), do: mandrill_message

  defp recipients(email) do
    []
    |> add_recipients(email.to, type: "to")
    |> add_recipients(email.cc, type: "cc")
    |> add_recipients(email.bcc, type: "bcc")
  end

  defp add_recipients(recipients, new_recipients, type: recipient_type) do
    Enum.reduce(new_recipients, recipients, fn(recipient, recipients) ->
      recipients ++ [%{
        name: recipient |> elem(0),
        email: recipient |> elem(1),
        type: recipient_type
      }]
    end)
  end

  defp api_path(%{private: %{template_name: _}}), do: @send_message_template_path
  defp api_path(_), do: @send_message_path

  defp headers do
    %{"content-type" => "application/json"}
  end

  defp request!(path, params) do
    HTTPoison.post!("#{base_uri}/#{path}", params, headers)
  end

  defp base_uri do
    Application.get_env(:bamboo, :mandrill_base_uri) || @default_base_uri
  end
end

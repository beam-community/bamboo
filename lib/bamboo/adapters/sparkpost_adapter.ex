defmodule Bamboo.SparkpostAdapter do
  @moduledoc """
  Sends email using Sparkpost's JSON API.

  Use this adapter to send emails through Sparkpost's API. Requires that an API
  key is set in the config. See `Bamboo.SparkpostHelper` for extra functions that
  can be used by `Bamboo.SparkpostAdapter` (tagging, merge vars, etc.)

  ## Example config

      # In config/config.exs, or config/prod.exs, etc.
      config :my_app, MyApp.Mailer,
        adapter: Bamboo.SparkpostAdapter,
        api_key: "my_api_key"

      # Define a Mailer. Maybe in lib/my_app/mailer.ex
      defmodule MyApp.Mailer do
        use Bamboo.Mailer, otp_app: :my_app
      end
  """

  @default_base_uri "https://api.sparkpost.com/"
  @send_message_path "api/v1/transmissions"
  @behaviour Bamboo.Adapter

  defmodule ApiError do
    defexception [:message]

    def exception(%{params: params, response: response}) do
      filtered_params = params |> Poison.decode! |> Map.put("key", "[FILTERED]")

      message = """
      There was a problem sending the email through the Sparkpost API.

      Here is the response:

      #{inspect response, limit: :infinity}


      Here are the params we sent:

      #{inspect filtered_params, limit: :infinity}
      """
      %ApiError{message: message}
    end
  end

  def deliver(email, config) do
    api_key = get_key(config)
    params = email |> convert_to_sparkpost_params |> Poison.encode!
    case request!(@send_message_path, params, api_key) do
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
    There was no API key set for the Sparkpost adapter.

    * Here are the config options that were passed in:

    #{inspect config}
    """
  end

  defp convert_to_sparkpost_params(email) do
    %{
      content: %{
        from: %{
          name: email.from |> elem(0),
          email: email.from |> elem(1),
        },
        subject: email.subject,
        text: email.text_body,
        html: email.html_body,
        reply_to: extract_reply_to(email),
        headers: drop_reply_to(email_headers(email)),
      },
      recipients: recipients(email),
    }
    |> add_message_params(email)
  end

  defp email_headers(email) do
    if email.cc == [] do
      email.headers
    else
      Map.put_new(email.headers, "CC", Enum.map(email.cc, fn({_,addr}) -> addr end) |> Enum.join(","))
    end
  end

  defp extract_reply_to(email) do
    email.headers["Reply-To"]
  end

  defp drop_reply_to(headers) do
    Map.delete(headers, "Reply-To")
  end

  defp add_message_params(mandrill_message, %{private: %{message_params: message_params}}) do
    Enum.reduce(message_params, mandrill_message, fn({key, value}, mandrill_message) ->
      Map.put(mandrill_message, key, value)
    end)
  end
  defp add_message_params(mandrill_message, _), do: mandrill_message

  defp recipients(email) do
    []
    |> add_recipients(email.to)
    |> add_b_cc(email.cc, email.to)
    |> add_b_cc(email.bcc, email.to)
  end

  defp add_recipients(recipients, new_recipients) do
    Enum.reduce(new_recipients, recipients, fn(recipient, recipients) ->
      recipients ++ [%{"address" => %{
        name: recipient |> elem(0),
        email: recipient |> elem(1),
      }}]
    end)
  end

  defp add_b_cc(recipients, new_recipients, to) do
    Enum.reduce(new_recipients, recipients, fn(recipient, recipients) ->
      recipients ++ [%{"address" => %{
        name: recipient |> elem(0),
        email: recipient |> elem(1),
        header_to: Enum.map(to, fn({_,addr}) -> addr end) |> Enum.join(","),
      }}]
    end)
  end

  defp headers(api_key) do
    %{"content-type" => "application/json", "authorization" => api_key}
  end

  defp request!(path, params, api_key) do
    HTTPoison.post!("#{base_uri}/#{path}", params, headers(api_key))
  end

  defp base_uri do
    Application.get_env(:bamboo, :mandrill_base_uri) || @default_base_uri
  end
end

defmodule Bamboo.CampaignMonitorAdapter do
  @moduledoc """
  Sends email using Campaign Monitor's JSON API.

  Use this adapter to send emails through Campaign Monitor's API. Requires that an API
  key is set in the config.

  If you would like to add a replyto header to your email, then simply pass it in
  using the header property or put_header function like so:

      put_header("reply-to", "foo@bar.com")

  ## Example config

      # In config/config.exs, or config.prod.exs, etc.
      config :my_app, MyApp.Mailer,
        adapter: Bamboo.CampaignMonitorAdapter,
        api_key: "my_api_key", # or System.get_env("API_KEY") 
        client_id: "my_client_id" # or System.get_env("CLIENT_ID")
      # Define a Mailer. Maybe in lib/my_app/mailer.ex
      defmodule MyApp.Mailer do
        use Bamboo.Mailer, otp_app: :my_app
      end
  """

  @service_name "CampaignMonitor"
  @default_base_uri "https://api.createsend.com/api/v3.2"
  @classic_email_path "/transactional/classicEmail/send"
  @smart_email_path "/transactional/smartEmail/[smartEmailId]/send"
  @behaviour Bamboo.Adapter

  alias Bamboo.Email
  import Bamboo.ApiError

  def deliver(email, config) do
    api_key = get_from_config(config, :api_key)
    body = email |> to_campaign_monitor_body(config) |> Jason.encode!()
    url = [base_uri(), get_path(email, config)]

    case :hackney.post(url, headers(api_key), body, [:with_body]) do
      {:ok, status, _headers, response} when status > 299 ->
        filtered_params = body |> Jason.decode!() |> Map.put("key", "[FILTERED]")
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
    Map.merge(config, %{api_key: get_from_config(config, :api_key)})
  end

  @doc false
  def supports_attachments?, do: false

  defp get_from_config(config, key) do
    value =
      case Map.get(config, key) do
        {:system, var} -> System.get_env(var)
        key -> key
      end

    if value in [nil, ""] do
      raise_api_key_error(config)
    else
      value
    end
  end

  defp raise_api_key_error(config) do
    raise ArgumentError, """
    There was no API key set for the Campaign Monitor adapter.

    * Here are the config options that were passed in:

    #{inspect(config)}
    """
  end

  defp headers(api_key) do
    [
      {"Content-Type", "application/json"},
      {"Accept", "application/json"},
      {"Authorization", "Basic #{Base.encode64(api_key <> ":x")}"}
    ]
  end

  # get the path based on the type of email (smart/classic)
  defp get_path(%Email{private: %{smart_email_id: smart_email_id}}, _) do
    String.replace(@smart_email_path, "[smartEmailId]", smart_email_id)
  end

  defp get_path(%Email{}, config) do
    client_id = get_from_config(config, :client_id)
    @classic_email_path <> "?clientID=#{client_id}"
  end

  defp to_campaign_monitor_body(email = %Email{}, _config) do
    %{}
    |> put_to(email)
    |> put_cc(email)
    |> put_bcc(email)
    |> put_from(email)
    |> put_reply_to(email)
    |> put_subject(email)
    |> put_html_body(email)
    |> put_text_body(email)
    |> put_consent_to_track(email)
    |> put_tracking_group(email)
    |> put_smart_email_data(email)
  end

  defp put_from(body, %Email{from: from}) do
    Map.put(body, "From", to_address(from))
  end

  defp put_to(body, %Email{to: to}) do
    put_addresses(body, "To", to)
  end

  defp put_cc(body, %Email{cc: []}), do: body

  defp put_cc(body, %Email{cc: cc}) do
    put_addresses(body, "CC", cc)
  end

  defp put_bcc(body, %Email{bcc: []}), do: body

  defp put_bcc(body, %Email{bcc: bcc}) do
    put_addresses(body, "BCC", bcc)
  end

  defp put_reply_to(body, %Email{headers: %{"reply-to" => reply_to}}) do
    Map.put(body, "ReplyTo", reply_to)
  end

  defp put_reply_to(body, _), do: body

  defp put_subject(body, %Email{subject: subject}) when not is_nil(subject),
    do: Map.put(body, "Subject", subject)

  defp put_subject(body, _), do: body

  defp put_html_body(body, %Email{html_body: nil}), do: body

  defp put_html_body(body, %Email{html_body: html_body}) do
    Map.put(body, "Html", html_body)
  end

  defp put_text_body(body, %Email{text_body: nil}), do: body

  defp put_text_body(body, %Email{text_body: text_body}) do
    Map.put(body, "Text", text_body)
  end

  defp put_consent_to_track(body, %Email{private: %{consent_to_track: "Yes"}}) do
    Map.put(body, "ConsentToTrack", "Yes")
  end

  defp put_consent_to_track(body, _) do
    Map.put(body, "ConsentToTrack", "No")
  end

  defp put_tracking_group(body, %Email{private: %{group: group}}) do
    Map.put(body, "Group", group)
  end

  defp put_tracking_group(body, _), do: body

  defp put_smart_email_data(body, %Email{private: %{smart_email_data: data}}) do
    Map.put(body, "Data", data)
  end

  defp put_smart_email_data(body, _), do: body

  defp put_addresses(body, _, []), do: body

  defp put_addresses(body, field, addresses),
    do: Map.put(body, field, Enum.map(addresses, &to_address/1))

  defp to_address({nil, address}), do: address
  defp to_address({"", address}), do: address
  defp to_address({name, address}), do: "#{name} <#{address}>"

  defp base_uri do
    Application.get_env(:bamboo, :campaign_monitor_base_uri) || @default_base_uri
  end
end

defmodule Bamboo.SMTPAdapter do
  @moduledoc """
  Sends email using SMTP protocol.

  Use this adapter to send emails through SMTP protocol. Requires that some
  settings are set in the config. See the example section below.

  ## Example config

      # In config/config.exs, or config.prod.exs, etc.
      config :my_app, MyApp.Mailer,
        adapter: Bamboo.SMTPAdapter,
        server: "smtp.domain",
        port: 1025,
        username: "your.name@your.domain"
        password: "pa55word",
        tls: :if_available, # can be `:always` or `:never`
        ssl: :false, # can be `:true`
        retries: 1

      # Define a Mailer. Maybe in lib/my_app/mailer.ex
      defmodule MyApp.Mailer do
        use Bamboo.Mailer, otp_app: :my_app
      end
  """

  @behaviour Bamboo.Adapter

  require Logger

  @required_configuration [:server, :port, :username, :password]
  @default_configuration %{tls: :if_available, ssl: :false, retries: 1, transport: :smtp}

  defmodule SMTPError do
    defexception [:message]

    def exception({reason, detail}) do
      message = """
      There was a problem sending the email through SMTP.

      The error is #{inspect reason}

      More detail below:

      #{inspect detail}
      """

      %SMTPError{message: message}
    end
  end

  def deliver(email, config) do
    gen_smtp_config =
      config
      |> to_gen_smtp_server_config

    email
    |> to_gen_smtp_message
    |> :gen_smtp_client.send_blocking(gen_smtp_config)
    |> handle_response
  end

  @doc false
  def handle_config(config) do
    config
    |> check_required_configuration
    |> put_default_configuration
  end

  defp handle_response({:error, reason, detail}) do
    raise SMTPError, {reason, detail}
  end
  defp handle_response(_) do
    :ok
  end

  defp add_bcc(body, %Bamboo.Email{bcc: recipients}) do
    add_smtp_body_line(body, :bcc, format_email(recipients, :bcc))
  end

  defp add_cc(body, %Bamboo.Email{cc: recipients}) do
    add_smtp_body_line(body, :cc, format_email(recipients, :cc))
  end

  defp add_from(body, %Bamboo.Email{from: from}) do
    add_smtp_body_line(body, :from, format_email(from, :from))
  end

  defp add_smtp_body_line(body, type, content) when is_list(content) do
    Enum.reduce(content, body, &add_smtp_body_line(&2, type, &1))
  end
  defp add_smtp_body_line(body, type, content) do
    body <> String.capitalize(to_string(type)) <> ": " <> content <> "\r\n"
  end

  defp add_html_body(body, %Bamboo.Email{html_body: _html_body}) do
    body
  end

  defp add_subject(body, %Bamboo.Email{subject: subject}) do
    add_smtp_body_line(body, :subject, subject)
  end

  defp add_text_body(body, %Bamboo.Email{text_body: text_body}) do
    body <> "\r\n" <> text_body
  end

  defp add_to(body, %Bamboo.Email{to: recipients}) do
    add_smtp_body_line(body, :to, format_email(recipients, :to))
  end

  defp aggregate_errors(config, key, errors) do
    config
    |> Map.fetch(key)
    |> build_error(key, errors)
  end

  defp apply_default_configuration({:ok, _value}, _default, config), do: config
  defp apply_default_configuration(:error, {key, default_value}, config) do
    Map.put_new(config, key, default_value)
  end

  defp body(%Bamboo.Email{} = email) do
    ""
    |> add_subject(email)
    |> add_from(email)
    |> add_bcc(email)
    |> add_cc(email)
    |> add_to(email)
    |> add_text_body(email)
    |> add_html_body(email)
  end

  defp build_error({:ok, _value}, _key, errors), do: errors
  defp build_error(:error, key, errors) do
    ["Key #{key} is required for SMTP Adapter" | errors]
  end

  defp check_required_configuration(config) do
    @required_configuration
    |> Enum.reduce([], &aggregate_errors(config, &1, &2))
    |> raise_on_missing_setting(config)
  end

  defp format_email(email, type) do
    email
    |> Bamboo.Formatter.format_email_address(type)
    |> format_email_address_as_string
  end

  defp format_email_address_as_string({nil, email}), do: email
  defp format_email_address_as_string({name, email}), do: "<#{email}> #{name}"
  defp format_email_address_as_string(emails) when is_list(emails) do
    Enum.map(emails, &format_email_address_as_string/1)
  end

  defp from(%Bamboo.Email{from: from}) do
    from
    |> format_email(:from)
  end

  defp put_default_configuration(config) do
    @default_configuration
    |> Enum.reduce(config, &put_default_configuration(&2, &1))
  end

  defp put_default_configuration(config, default = {key, _default_value}) do
    config
    |> Map.fetch(key)
    |> apply_default_configuration(default, config)
  end

  defp raise_on_missing_setting([], config), do: config
  defp raise_on_missing_setting(errors, config) do
    formatted_errors =
      errors
      |> Enum.map(&("* #{&1}"))
      |> Enum.join("\n")

    raise ArgumentError, """
    The following settings have not been found in your settings:

    #{formatted_errors}

    They are required to make the SMTP adapter work. Here you configuration:

    #{inspect config}
    """
  end

  defp to(%Bamboo.Email{to: to, cc: cc, bcc: bcc}) do
    to
    |> Enum.into(cc)
    |> Enum.into(bcc)
    |> format_email(:to)
  end

  defp to_gen_smtp_message(%Bamboo.Email{} = email) do
    {from(email), to(email), body(email)}
  end

  defp to_gen_smtp_server_config(config) do
    Enum.reduce(config, [], &to_gen_smtp_server_config/2)
  end

  defp to_gen_smtp_server_config({:server, value}, config) do
    [{:relay, value} | config]
  end
  defp to_gen_smtp_server_config({:username, value}, config) do
    [{:username, value} | config]
  end
  defp to_gen_smtp_server_config({:password, value}, config) do
    [{:password, value} | config]
  end
  defp to_gen_smtp_server_config({:tls, value}, config) do
    [{:tls, value} | config]
  end
  defp to_gen_smtp_server_config({:port, value}, config) do
    [{:port, value} | config]
  end
  defp to_gen_smtp_server_config({:ssl, value}, config) do
    [{:ssl, value} | config]
  end
  defp to_gen_smtp_server_config({:retries, value}, config) do
    [{:retries, value} | config]
  end
 defp to_gen_smtp_server_config({_key, _value}, config) do
    config
  end
end

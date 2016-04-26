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
  @default_configuration [tls: :if_available, ssl: :false, retries: 1, transport: :smtp]

  defmodule SMTPError do
    defexception [:message]

    def exception({:error, reason, detail}) do
      message = """
      There was a problem sending the email through SMTP.

      The error is #{inspect reason}

      More detail below:

      #{inspect detail}
      """

      %SMTPError{message: message}
    end
  end

  def deliver(email, _config) do
    email
    |> to_mailer_message
    |> Mailer.send
    |> check_smtp_response
  end

  @doc false
  def handle_config(config) do
    config
    |> check_required_configuration
    |> put_default_configuration
    |> define_mailer_environment
  end

  defp add_bcc(%Mailer.Email.Multipart{} = email, %Bamboo.Email{bcc: bcc})
  when bcc == nil or bcc == [] do
    email
  end
  defp add_bcc(%Mailer.Email.Multipart{} = email, %Bamboo.Email{} = _from_email) do
    not_yet_supported

    email
  end

  defp add_cc(%Mailer.Email.Multipart{} = email, %Bamboo.Email{cc: cc})
  when cc == nil or cc == [] do
    email
  end
  defp add_cc(%Mailer.Email.Multipart{} = email, %Bamboo.Email{} = _from_email) do
    not_yet_supported

    email
  end

  defp add_date(%Mailer.Email.Multipart{} = email, %Bamboo.Email{} = _from_email) do
    Mailer.Email.Multipart.add_date(email, Mailer.Util.localtime_to_str)
  end

  defp add_from(%Mailer.Email.Multipart{} = email, %Bamboo.Email{from: from}) do
    sender =
      from
      |> Bamboo.Formatter.format_email_address(:from)
      |> format_email_address_as_string

    Mailer.Email.Multipart.add_from(email, sender)
  end

  defp add_html_body(%Mailer.Email.Multipart{} = email, %Bamboo.Email{html_body: html_body}) do
    Mailer.Email.Multipart.add_html_body(email, html_body)
  end

  defp add_message_id(%Mailer.Email.Multipart{} = email, %Bamboo.Email{from: from}) do
    message_id =
      from
      |> Bamboo.Formatter.format_email_address(:from)
      |> format_email_address_as_string
      |> Mailer.Message.Id.create

    Mailer.Email.Multipart.add_message_id(email, message_id)
  end

  defp add_subject(%Mailer.Email.Multipart{} = email, %Bamboo.Email{subject: subject}) do
    Mailer.Email.Multipart.add_subject(email, subject)
  end

  defp add_text_body(%Mailer.Email.Multipart{} = email, %Bamboo.Email{text_body: text_body}) do
    Mailer.Email.Multipart.add_text_body(email, text_body)
  end

  defp add_to(%Mailer.Email.Multipart{} = email, %Bamboo.Email{to: to}) do
    to
    |> Bamboo.Formatter.format_email_address(:to)
    |> format_email_address_as_string
    |> Enum.reduce(email, &Mailer.Email.Multipart.add_to(&2, &1))
  end

  defp aggregate_errors(config, key, errors) do
    config
    |> Map.fetch(key)
    |> build_error(key, errors)
  end

  defp build_error({:ok, _value}, _key, errors), do: errors
  defp build_error(:error, key, errors) do
    Dict.put_new(errors, key, "Key #{key} is required for SMTP Adapter")
  end

  defp check_required_configuration(config) do
    @required_configuration
    |> Enum.reduce([], &aggregate_errors(config, &1, &2))
    |> raise_on_missing_setting(config)
  end

  defp check_smtp_response({:error, _reason, _detail} = error), do: raise(SMTPError, error)
  defp check_smtp_response(_success), do: :ok

  defp define_mailer_environment(config) do
    mailer_config =
      config
      |> Enum.into([])
      |> Enum.filter(&part_of_mailer_configuration?/1)

    Application.put_env(:mailer, :smtp_client, mailer_config)

    config
  end

  defp format_email_address_as_string({nil, email}), do: email
  defp format_email_address_as_string({_name, email}), do: email
  defp format_email_address_as_string(emails) when is_list(emails) do
    Enum.map(emails, &format_email_address_as_string/1)
  end

  defp not_yet_supported, do: Logger.warn "BCC feature is not supported by SMTP adapter"

  defp part_of_mailer_configuration?({key, _value}) when key in @required_configuration, do: true
  defp part_of_mailer_configuration?({key, _value}) do
    @default_configuration
    |> Enum.map(fn ({default_key, _default_value}) -> default_key end)
    |> Enum.any?(&(&1 == key))
  end

  defp put_default_configuration(config) do
    @default_configuration
    |> Enum.reduce(config, &put_default_configuration(&2, &1))
  end

  defp put_default_configuration(config, default = {key, _default_value}) do
    config
    |> Dict.fetch(key)
    |> apply_default_configuration(default, config)
  end

  defp apply_default_configuration({:ok, _value}, _default, config), do: config
  defp apply_default_configuration(:error, {key, default_value}, config) do
    Dict.put_new(config, key, default_value)
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

  defp to_mailer_message(%Bamboo.Email{} = email) do
    Mailer.Email.Multipart.create
    |> add_from(email)
    |> add_to(email)
    |> add_bcc(email)
    |> add_cc(email)
    |> add_subject(email)
    |> add_message_id(email)
    |> add_date(email)
    |> add_html_body(email)
    |> add_text_body(email)
  end
end

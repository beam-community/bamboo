defmodule Bamboo.SMTPAdapterTest do
  use ExUnit.Case

  alias Bamboo.Email
  alias Bamboo.SMTPAdapter

  defmodule FakeGenSMTP do
    use GenServer

    def start_link do
      GenServer.start_link(__MODULE__, [], name: __MODULE__)
    end

    def send_blocking(email, config) do
      GenServer.call(__MODULE__, {:send_email, {email, config}})
    end

    def fetch_sent_emails do
      GenServer.call(__MODULE__, :fetch_emails)
    end

    def handle_call(:fetch_emails, _from, state) do
      {:reply, state, state}
    end

    def handle_call({:send_email, {email, config}}, {pid, _reference}, state) do
      case check_validity(email, config) do
        :ok ->
          {:reply, :ok, [{email, config}|state]}
        error ->
          {:reply, error, state}
      end
    end

    defp check_validity(email, config) do
      with :ok <- check_configuration(config),
           :ok <- check_email(email),
      do: :ok
    end

    defp check_configuration(config) do
      case Keyword.fetch(config, :relay) do
        {:ok, wrong_domain = "wrong.smtp.domain"} ->
          {:error, :retries_exceeded, {:network_failure, wrong_domain, {:error, :nxdomain}}}
        _ ->
          :ok
      end
    end

    defp check_email({from, _to, _raw}) do
      case from do
        "<wrong@user.com> Wrong User" ->
          {:error, :no_more_hosts, {:permanent_failure,
                                    "an-smtp-adddress", "554 Message rejected: Email address is not verified.\r\n"}}
        _ ->
          :ok
      end
    end
  end

  @configuration %{
    adapter: SMTPAdapter,
    server: "smtp.domain",
    port: 1025,
    username: "your.name@your.domain",
    password: "pa55word",
    transport: FakeGenSMTP
  }

  @email [
    from: {"John Doe", "john@doe.com"},
    to: [{"Jane Doe", "jane@doe.com"}],
    cc: [{"Richard Roe", "richard@roe.com"}],
    bcc: [{"Mary Major", "mary@major.com"},
          {"Joe Major", "joe@major.com"}],
    subject: "Hello from Bamboo",
    html_body: "<h1>Bamboo is awesome!</h1>",
    text_body: "*Bamboo is awesome!*",
    headers: %{
      "Reply-To" => "reply@doe.com"
    }
  ]

  setup do
    FakeGenSMTP.start_link

    :ok
  end

  test "raises if the server is nil" do
    assert_raise ArgumentError, ~r/Key server is required/, fn ->
      SMTPAdapter.handle_config(configuration(%{server: nil}))
    end
  end

  test "raises if the port is nil" do
    assert_raise ArgumentError, ~r/Key port is required/, fn ->
      SMTPAdapter.handle_config(configuration(%{port: nil}))
    end
  end

  test "raises if the username is nil" do
    assert_raise ArgumentError, ~r/Key username is required/, fn ->
      SMTPAdapter.handle_config(configuration(%{username: nil}))
    end
  end

  test "raises if the password is nil" do
    assert_raise ArgumentError, ~r/Key password is required/, fn ->
      SMTPAdapter.handle_config(configuration(%{password: nil}))
    end
  end

  test "sets default tls key if not present" do
    %{tls: tls} = SMTPAdapter.handle_config(configuration)

    assert :if_available == tls
  end

  test "doesn't set a default tls key if present" do
    %{tls: tls} = SMTPAdapter.handle_config(configuration(%{tls: :always}))

    assert :always == tls
  end

  test "sets default ssl key if not present" do
    %{ssl: ssl} = SMTPAdapter.handle_config(configuration)

    refute ssl
  end

  test "doesn't set a default ssl key if present" do
    %{ssl: ssl} = SMTPAdapter.handle_config(configuration(%{ssl: true}))

    assert ssl
  end

  test "sets default retries key if not present" do
    %{retries: retries} = SMTPAdapter.handle_config(configuration)

    assert retries == 1
  end

  test "doesn't set a default retries key if present" do
    %{retries: retries} = SMTPAdapter.handle_config(configuration(%{retries: 42}))

    assert retries == 42
  end

  test "emails raise an exception when configuration is wrong" do
    bamboo_email = new_email
    bamboo_config = configuration(%{server: "wrong.smtp.domain"})

    assert_raise SMTPAdapter.SMTPError, ~r/network_failure/, fn ->
      SMTPAdapter.deliver(bamboo_email, bamboo_config)
    end
  end

  test "emails raise an exception when email can't be sent" do
    bamboo_email = new_email(from: {"Wrong User", "wrong@user.com"})
    bamboo_config = configuration

    assert_raise SMTPAdapter.SMTPError, ~r/554 Message rejected/, fn ->
      SMTPAdapter.deliver(bamboo_email, bamboo_config)
    end
  end

  test "emails looks fine when only text body is set" do
    bamboo_email = new_email(text_body: nil)
    bamboo_config = configuration

    :ok = SMTPAdapter.deliver(bamboo_email, bamboo_config)

    assert 1 = length(FakeGenSMTP.fetch_sent_emails)

    [{{from, to, raw_email}, gen_smtp_config}] = FakeGenSMTP.fetch_sent_emails

    [multipart_header] =
      Regex.run(
        ~r{Content-Type: multipart/alternative; boundary="([^"]+)"\r\n},
        raw_email,
        capture: :all_but_first)

    assert format_email_as_string(bamboo_email.from) == from
    assert format_email(bamboo_email.to ++ bamboo_email.cc ++ bamboo_email.bcc) == to

    assert String.contains?(raw_email, "Subject: #{bamboo_email.subject}\r\n")
    assert String.contains?(raw_email, "From: #{format_email_as_string(bamboo_email.from)}\r\n")
    assert String.contains?(raw_email, "To: #{format_email_as_string(bamboo_email.to)}\r\n")
    assert String.contains?(raw_email, "Cc: #{format_email_as_string(bamboo_email.cc)}\r\n")
    assert String.contains?(raw_email, "Bcc: #{format_email_as_string(bamboo_email.bcc)}\r\n")
    assert String.contains?(raw_email, "Reply-To: reply@doe.com\r\n")
    assert String.contains?(raw_email, "MIME-Version: 1.0\r\n")
    assert String.contains?(raw_email, "--#{multipart_header}\r\n" <>
                                        "Content-Type: text/html;charset=UTF-8\r\n" <>
                                        "Content-ID: html-body\r\n" <>
                                        "#{bamboo_email.html_body}\r\n")
    refute String.contains?(raw_email, "--#{multipart_header}\r\n" <>
                                        "Content-Type: text/plain;charset=UTF-8\r\n" <>
                                        "Content-ID: text-body\r\n")

    assert_configuration bamboo_config, gen_smtp_config
  end

  test "emails looks fine when only HTML body is set" do
    bamboo_email = new_email(html_body: nil)
    bamboo_config = configuration

    :ok = SMTPAdapter.deliver(bamboo_email, bamboo_config)

    assert 1 = length(FakeGenSMTP.fetch_sent_emails)

    [{{from, to, raw_email}, gen_smtp_config}] = FakeGenSMTP.fetch_sent_emails

    [multipart_header] =
      Regex.run(
        ~r{Content-Type: multipart/alternative; boundary="([^"]+)"\r\n},
        raw_email,
        capture: :all_but_first)

    assert format_email_as_string(bamboo_email.from) == from
    assert format_email(bamboo_email.to ++ bamboo_email.cc ++ bamboo_email.bcc) == to

    assert String.contains?(raw_email, "Subject: #{bamboo_email.subject}\r\n")
    assert String.contains?(raw_email, "From: #{format_email_as_string(bamboo_email.from)}\r\n")
    assert String.contains?(raw_email, "To: #{format_email_as_string(bamboo_email.to)}\r\n")
    assert String.contains?(raw_email, "Cc: #{format_email_as_string(bamboo_email.cc)}\r\n")
    assert String.contains?(raw_email, "Bcc: #{format_email_as_string(bamboo_email.bcc)}\r\n")
    assert String.contains?(raw_email, "Reply-To: reply@doe.com\r\n")
    assert String.contains?(raw_email, "MIME-Version: 1.0\r\n")
    refute String.contains?(raw_email, "--#{multipart_header}\r\n" <>
                                        "Content-Type: text/html;charset=UTF-8\r\n" <>
                                        "Content-ID: html-body\r\n")
    assert String.contains?(raw_email, "--#{multipart_header}\r\n" <>
                                        "Content-Type: text/plain;charset=UTF-8\r\n" <>
                                        "Content-ID: text-body\r\n" <>
                                        "#{bamboo_email.text_body}\r\n")

    assert_configuration bamboo_config, gen_smtp_config
  end

  test "emails looks fine when text and HTML bodys are sets" do
    bamboo_email = new_email
    bamboo_config = configuration

    :ok = SMTPAdapter.deliver(bamboo_email, bamboo_config)

    assert 1 = length(FakeGenSMTP.fetch_sent_emails)

    [{{from, to, raw_email}, gen_smtp_config}] = FakeGenSMTP.fetch_sent_emails

    [multipart_header] =
      Regex.run(
        ~r{Content-Type: multipart/alternative; boundary="([^"]+)"\r\n},
        raw_email,
        capture: :all_but_first)

    assert format_email_as_string(bamboo_email.from) == from
    assert format_email(bamboo_email.to ++ bamboo_email.cc ++ bamboo_email.bcc) == to

    assert String.contains?(raw_email, "Subject: #{bamboo_email.subject}\r\n")
    assert String.contains?(raw_email, "From: #{format_email_as_string(bamboo_email.from)}\r\n")
    assert String.contains?(raw_email, "To: #{format_email_as_string(bamboo_email.to)}\r\n")
    assert String.contains?(raw_email, "Cc: #{format_email_as_string(bamboo_email.cc)}\r\n")
    assert String.contains?(raw_email, "Bcc: #{format_email_as_string(bamboo_email.bcc)}\r\n")
    assert String.contains?(raw_email, "Reply-To: reply@doe.com\r\n")
    assert String.contains?(raw_email, "MIME-Version: 1.0\r\n")
    assert String.contains?(raw_email, "--#{multipart_header}\r\n" <>
                                        "Content-Type: text/html;charset=UTF-8\r\n" <>
                                        "Content-ID: html-body\r\n" <>
                                        "#{bamboo_email.html_body}\r\n")
    assert String.contains?(raw_email, "--#{multipart_header}\r\n" <>
                                        "Content-Type: text/plain;charset=UTF-8\r\n" <>
                                        "Content-ID: text-body\r\n" <>
                                        "#{bamboo_email.text_body}\r\n")

    assert_configuration bamboo_config, gen_smtp_config
  end

  defp format_email({name, email}), do: "<#{email}> #{name}"
  defp format_email(emails) when is_list(emails) do
    emails |> Enum.map(&format_email/1)
  end

  defp format_email_as_string(emails) when is_list(emails) do
    format_email(emails) |> Enum.join(", ")
  end
  defp format_email_as_string(email) do
    format_email(email)
  end

  defp assert_configuration(bamboo_config, gen_smtp_config) do
    assert bamboo_config[:server] == gen_smtp_config[:relay]
    assert bamboo_config[:port] == gen_smtp_config[:port]
    assert bamboo_config[:username] == gen_smtp_config[:username]
    assert bamboo_config[:password] == gen_smtp_config[:password]
    assert bamboo_config[:tls] == gen_smtp_config[:tls]
    assert bamboo_config[:ssl] == gen_smtp_config[:ssl]
    assert bamboo_config[:retries] == gen_smtp_config[:retries]
  end

  defp configuration(override \\ %{}), do: Map.merge(@configuration, override)

  defp new_email(override \\ []) do
    @email
    |> Keyword.merge(override)
    |> Email.new_email
    |> Bamboo.Mailer.normalize_addresses
  end
end

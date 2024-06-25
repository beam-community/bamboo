defmodule Bamboo.MailerTest do
  use ExUnit.Case
  alias Bamboo.Email

  @mailer_config adapter: __MODULE__.DefaultAdapter, foo: :bar, interceptors: nil

  setup context do
    config =
      Keyword.merge(
        @mailer_config,
        [adapter: context[:adapter], interceptors: context[:interceptors]],
        fn
          _key, default, nil -> default
          _key, _default, override -> override
        end
      )

    Application.put_env(:bamboo, __MODULE__.Mailer, config)
    Process.register(self(), :mailer_test)
    on_exit(fn -> Application.delete_env(:bamboo, __MODULE__.Mailer) end)
    :ok
  end

  defmodule(Mailer, do: use(Bamboo.Mailer, otp_app: :bamboo))

  defmodule DefaultAdapter do
    def deliver(email, config) do
      send(:mailer_test, {:deliver, email, config})
      {:ok, email}
    end

    def handle_config(config), do: config

    def supports_attachments?, do: true
  end

  defmodule FailureAdapter do
    def deliver(_email, _config) do
      {:error, %Bamboo.ApiError{message: "invalid email"}}
    end

    def handle_config(config), do: config

    def supports_attachments?, do: true
  end

  test "deliver_now/1 returns :ok tuple with sent email" do
    address = "foo@bar.com"
    email = new_email(from: address, to: address, cc: address, bcc: address)

    {:ok, delivered_email} = Mailer.deliver_now(email)

    assert_received {:deliver, ^delivered_email, _}
  end

  @tag adapter: FailureAdapter
  test "deliver_now/1 returns errors if adapter fails" do
    address = "foo@bar.com"
    email = new_email(from: address, to: address, cc: address, bcc: address)

    {:error, %Bamboo.ApiError{}} = Mailer.deliver_now(email)

    refute_received {:deliver, _, _}
  end

  @tag adapter: FailureAdapter
  test "deliver_now!/1 raises errors if adapter fails" do
    address = "foo@bar.com"
    email = new_email(from: address, to: address, cc: address, bcc: address)

    assert_raise Bamboo.ApiError, fn ->
      Mailer.deliver_now!(email)
    end
  end

  test "deliver_now!/1 returns email sent" do
    address = "foo@bar.com"
    email = new_email(from: address, to: address, cc: address, bcc: address)

    delivered_email = Mailer.deliver_now!(email)

    assert_received {:deliver, ^delivered_email, _}
  end

  test "deliver_now/1 converts binary addresses to %{name: name, email: email}" do
    address = "foo@bar.com"
    email = new_email(from: address, to: address, cc: address, bcc: address)

    Mailer.deliver_now(email)

    converted_address = {nil, address}
    assert_received {:deliver, delivered_email, _}
    assert delivered_email.from == converted_address
    assert delivered_email.to == [converted_address]
    assert delivered_email.cc == [converted_address]
    assert delivered_email.bcc == [converted_address]
  end

  test "converts structs with custom protocols" do
    user = %Bamboo.Test.User{first_name: "Paul", email: "foo@bar.com"}
    email = new_email(from: user, to: user, cc: user, bcc: user)

    Mailer.deliver_now(email)

    converted_recipient = {user.first_name, user.email}
    assert_received {:deliver, delivered_email, _}
    assert delivered_email.from == {"#{user.first_name} (MyApp)", user.email}
    assert delivered_email.to == [converted_recipient]
    assert delivered_email.cc == [converted_recipient]
    assert delivered_email.bcc == [converted_recipient]
  end

  test "deliver_later/1 calls deliver on the adapter" do
    email = new_email()

    Mailer.deliver_later(email)

    assert_receive {:deliver, delivered_email, _config}
    assert delivered_email == Bamboo.Mailer.normalize_addresses(email)
  end

  test "deliver_later/1 returns the email that will be sent" do
    email = new_email()

    {:ok, delivered_email} = Mailer.deliver_later(email)

    assert_receive {:deliver, ^delivered_email, _config}
  end

  test "deliver_now/1 wraps the recipients in a list" do
    address = {"Someone", "foo@bar.com"}
    email = new_email(to: address, cc: address, bcc: address)

    Mailer.deliver_now(email)

    assert_received {:deliver, delivered_email, _}
    assert delivered_email.to == [address]
    assert delivered_email.cc == [address]
    assert delivered_email.bcc == [address]
  end

  test "sets a default deliver_later_strategy if none is set" do
    email = new_email(to: "foo@bar.com")

    Mailer.deliver_now(email)

    assert_received {:deliver, _email, config}
    assert config.deliver_later_strategy == Bamboo.TaskSupervisorStrategy
  end

  test "deliver_now/1 calls the adapter with the email and config as a map" do
    email = new_email(to: "foo@bar.com")

    expected_final_config =
      @mailer_config
      |> Enum.into(%{})
      |> Map.put(:deliver_later_strategy, Bamboo.TaskSupervisorStrategy)

    {:ok, returned_email} = Mailer.deliver_now(email)

    assert returned_email == Bamboo.Mailer.normalize_addresses(email)
    assert_received {:deliver, %Bamboo.Email{}, ^expected_final_config}
  end

  test "deliver/1 raises a helpful error message" do
    assert_raise RuntimeError, ~r/Use deliver_now/, fn ->
      Mailer.deliver(:anything)
    end
  end

  test "deliver_now/1 with no from address returns an error" do
    {:error, %Bamboo.EmptyFromAddressError{}} = Mailer.deliver_now(new_email(from: nil))
    {:error, %Bamboo.EmptyFromAddressError{}} = Mailer.deliver_now(new_email(from: {"foo", nil}))
  end

  test "deliver_now!/1 with no from address raises an error" do
    assert_raise Bamboo.EmptyFromAddressError, fn ->
      Mailer.deliver_now!(new_email(from: nil))
    end

    assert_raise Bamboo.EmptyFromAddressError, fn ->
      Mailer.deliver_now!(new_email(from: {"foo", nil}))
    end
  end

  test "deliver_now/1 with empty recipient lists does not deliver email" do
    {:ok, email} = new_email(to: [], cc: [], bcc: []) |> Mailer.deliver_now()
    refute_received {:deliver, ^email, _}

    {:ok, email} = new_email(to: [], cc: nil, bcc: nil) |> Mailer.deliver_now()
    refute_received {:deliver, ^email, _}

    {:ok, email} = new_email(to: nil, cc: [], bcc: nil) |> Mailer.deliver_now()
    refute_received {:deliver, ^email, _}

    {:ok, email} = new_email(to: nil, cc: nil, bcc: []) |> Mailer.deliver_now()
    refute_received {:deliver, ^email, _}
  end

  test "deliver_later/1 with empty lists for recipients does not deliver email" do
    new_email(to: [], cc: [], bcc: []) |> Mailer.deliver_later()
    refute_received {:deliver, _, _}

    new_email(to: [], cc: nil, bcc: nil) |> Mailer.deliver_later()
    refute_received {:deliver, _, _}

    new_email(to: nil, cc: [], bcc: nil) |> Mailer.deliver_later()
    refute_received {:deliver, _, _}

    new_email(to: nil, cc: nil, bcc: []) |> Mailer.deliver_later()
    refute_received {:deliver, _, _}
  end

  test "returns an error if all recipients are nil" do
    {:error, %Bamboo.NilRecipientsError{}} =
      new_email(to: nil, cc: nil, bcc: nil)
      |> Mailer.deliver_now()

    {:error, %Bamboo.NilRecipientsError{}} =
      new_email(to: {"foo", nil})
      |> Mailer.deliver_now()

    {:error, %Bamboo.NilRecipientsError{}} =
      new_email(to: [{"foo", nil}])
      |> Mailer.deliver_now()

    {:error, %Bamboo.NilRecipientsError{}} =
      new_email(to: [nil])
      |> Mailer.deliver_now()
  end

  test "raises on deliver_now! if all recipients are nil" do
    assert_raise Bamboo.NilRecipientsError, fn ->
      new_email(to: nil, cc: nil, bcc: nil)
      |> Mailer.deliver_now!()
    end

    assert_raise Bamboo.NilRecipientsError, fn ->
      new_email(to: {"foo", nil})
      |> Mailer.deliver_now!()
    end

    assert_raise Bamboo.NilRecipientsError, fn ->
      new_email(to: [{"foo", nil}])
      |> Mailer.deliver_now!()
    end

    assert_raise Bamboo.NilRecipientsError, fn ->
      new_email(to: [nil])
      |> Mailer.deliver_now!()
    end
  end

  test "raises an error if an address does not have a protocol implemented" do
    email = new_email(from: 1)

    assert_raise Protocol.UndefinedError, fn ->
      Mailer.deliver_now(email)
    end
  end

  test "raises if a map is passed in" do
    email = new_email(from: %{foo: :bar})

    assert_raise ArgumentError, fn ->
      Mailer.deliver_now(email)
    end
  end

  test "raises an error if deliver_now or deliver_later or the ! equivalents are called directly" do
    email = new_email(from: %{foo: :bar})

    assert_raise RuntimeError, ~r/cannot call Bamboo.Mailer/, fn ->
      Bamboo.Mailer.deliver_now(email)
    end

    assert_raise RuntimeError, ~r/cannot call Bamboo.Mailer/, fn ->
      Bamboo.Mailer.deliver_now!(email)
    end

    assert_raise RuntimeError, ~r/cannot call Bamboo.Mailer/, fn ->
      Bamboo.Mailer.deliver_later(email)
    end

    assert_raise RuntimeError, ~r/cannot call Bamboo.Mailer/, fn ->
      Bamboo.Mailer.deliver_later!(email)
    end
  end

  describe "attachments" do
    defmodule AdapterWithoutAttachmentSupport do
      def deliver(_email, _config), do: {:ok, :noop}

      def handle_config(config), do: config

      def supports_attachments?, do: false
    end

    @tag adapter: AdapterWithoutAttachmentSupport
    test "returns errors if adapter does not support attachments and attachments are sent" do
      path = Path.join(__DIR__, "../../support/attachment.docx")
      email = new_email(to: "foo@bar.com") |> Email.put_attachment(path)

      assert {:error, error} = Mailer.deliver_now(email)
      assert error =~ "does not support attachments"

      assert {:error, error} = Mailer.deliver_later(email)
      assert error =~ "does not support attachments"
    end

    @tag adapter: AdapterWithoutAttachmentSupport
    test "raise errors with deliver_x! if adapter does not support attachments and attachments are sent" do
      path = Path.join(__DIR__, "../../support/attachment.docx")
      email = new_email(to: "foo@bar.com") |> Email.put_attachment(path)

      assert_raise RuntimeError, ~r/does not support attachments/, fn ->
        Mailer.deliver_now!(email)
      end

      assert_raise RuntimeError, ~r/does not support attachments/, fn ->
        Mailer.deliver_later!(email)
      end
    end

    @tag adapter: AdapterWithoutAttachmentSupport
    test "does not raise if no attachments are on the email" do
      email = new_email(to: "foo@bar.com")
      Mailer.deliver_now(email)
    end

    @tag adapter: DefaultAdapter
    test "does not raise if adapter supports attachments" do
      path = Path.join(__DIR__, "../../support/attachment.docx")
      email = new_email(to: "foo@bar.com") |> Email.put_attachment(path)

      Mailer.deliver_now(email)

      assert_received {:deliver, _email, _config}
    end
  end

  describe "configuration" do
    defmodule CustomConfigAdapter do
      def deliver(email, config) do
        send(:mailer_test, {:deliver, email, config})
        {:ok, email}
      end

      def handle_config(config) do
        config |> Map.put(:custom_key, "Set by the adapter")
      end
    end

    @tag adapter: CustomConfigAdapter
    test "uses adapter's handle_config/1 to customize or validate the config" do
      email = new_email(to: "foo@bar.com")

      Mailer.deliver_now(email)

      assert_received {:deliver, _email, config}
      assert config.custom_key == "Set by the adapter"
    end

    test "deliver_now/2 overrides Adapter config with the 'config:' option" do
      email = new_email(to: "foo@bar.com")

      override_config = %{
        foo: :baz,
        something: :new
      }

      Mailer.deliver_now(email, config: override_config)

      assert_received {:deliver, _email, config}
      assert config.foo == :baz
      assert config.something == :new
    end

    test "deliver_later/2 overrides Adapter config with the 'config:' option" do
      email = new_email(to: "baz@qux.com")

      override_config = %{
        foo: :qux,
        something: :groovy
      }

      Mailer.deliver_later(email, config: override_config)

      assert_receive {:deliver, _email, config}
      assert config.foo == :qux
      assert config.something == :groovy
    end
  end

  describe "option to return response" do
    defmodule ResponseAdapter do
      def deliver(_email, _config) do
        response = %{status_code: 202, headers: [%{}], body: ""}
        send(:mailer_test, response)
        {:ok, response}
      end

      def handle_config(config), do: config
    end

    @tag adapter: ResponseAdapter
    test "deliver_now/2 returns {:ok, email, response} when passing response: true option" do
      email = new_email(to: "foo@bar.com")

      {:ok, email, response} = Mailer.deliver_now(email, response: true)

      assert %Email{} = email
      assert %{body: _, headers: _, status_code: _} = response
    end

    @tag adapter: ResponseAdapter
    test "deliver_now/1 does not return response when not passing in response: true option" do
      email = new_email(to: "foo@bar.com")

      {:ok, email} = Mailer.deliver_now(email)

      assert %Email{} = email
    end

    @tag adapter: ResponseAdapter
    test "deliver_now!/1 returns email when not passing in response: true option" do
      email = new_email(to: "foo@bar.com")

      email = Mailer.deliver_now!(email)

      assert %Email{} = email
    end

    @tag adapter: ResponseAdapter
    test "deliver_now/1 returns email and response when passing in both response: true and a custom config option" do
      email = new_email(to: "foo@bar.com")

      {:ok, email, response} = Mailer.deliver_now(email, config: %{}, response: true)

      assert %Email{} = email
      assert %{body: _, headers: _, status_code: _} = response
    end

    @tag adapter: ResponseAdapter
    test "does not return a response if email is not sent" do
      email = new_email(to: [], cc: [], bcc: [])

      {:ok, email} = Mailer.deliver_now(email, response: true)

      refute_received {:deliver, ^email, _}
    end
  end

  describe "interceptors" do
    @tag interceptors: [Bamboo.DenyListInterceptor, Bamboo.EnvInterceptor]
    test "deliver_now/1 must apply interceptors and send email if not intercepted" do
      email = new_email(to: "foo@bar.com")
      assert {:ok, %Bamboo.Email{blocked: false}} = Mailer.deliver_now(email)

      assert_receive {:deliver, %Bamboo.Email{to: [{nil, "foo@bar.com"}], subject: "test - "}, _config}
    end

    @tag interceptors: [Bamboo.DenyListInterceptor, Bamboo.EnvInterceptor]
    test "deliver_now/1 must apply interceptors and block email if intercepted" do
      email = new_email(to: "blocked@blocked.com")
      assert {:ok, %Bamboo.Email{blocked: true}} = Mailer.deliver_now(email)
      refute_receive {:deliver, %Bamboo.Email{to: [{nil, "blocked@blocked.com"}]}, _config}
    end

    @tag interceptors: [Bamboo.DenyListInterceptor, Bamboo.EnvInterceptor]
    test "deliver_now!/1 must apply interceptors and send email if not intercepted" do
      email = new_email(to: "foo@bar.com")
      assert %Bamboo.Email{blocked: false} = Mailer.deliver_now!(email)

      assert_receive {:deliver, %Bamboo.Email{to: [{nil, "foo@bar.com"}], subject: "test - "}, _config}
    end

    @tag interceptors: [Bamboo.DenyListInterceptor, Bamboo.EnvInterceptor]
    test "deliver_now!/1 must apply interceptors and block email if intercepted" do
      email = new_email(to: "blocked@blocked.com")

      assert %Bamboo.Email{blocked: true} = Mailer.deliver_now!(email)

      refute_receive {:deliver, %Bamboo.Email{to: [{nil, "blocked@blocked.com"}]}, _config}
    end

    @tag interceptors: [Bamboo.DenyListInterceptor, Bamboo.EnvInterceptor]
    test "deliver_later/1 must apply interceptors and send email if not intercepted" do
      email = new_email(to: "foo@bar.com")
      assert {:ok, %Bamboo.Email{blocked: false}} = Mailer.deliver_later(email)

      assert_receive {:deliver, %Bamboo.Email{to: [{nil, "foo@bar.com"}], subject: "test - "}, _config}
    end

    @tag interceptors: [Bamboo.DenyListInterceptor, Bamboo.EnvInterceptor]
    test "deliver_later/1 must apply interceptors and block email if intercepted" do
      email = new_email(to: "blocked@blocked.com")

      assert {:ok, %Bamboo.Email{blocked: true}} = Mailer.deliver_later(email)

      refute_receive {:deliver, %Bamboo.Email{to: [{nil, "blocked@blocked.com"}]}, _config}
    end

    @tag interceptors: [Bamboo.DenyListInterceptor, Bamboo.EnvInterceptor]
    test "deliver_later!/1 must apply interceptors and send email if not intercepted" do
      email = new_email(to: "foo@bar.com")
      assert %Bamboo.Email{blocked: false} = Mailer.deliver_later!(email)

      assert_receive {:deliver, %Bamboo.Email{to: [{nil, "foo@bar.com"}], subject: "test - "}, _config}
    end

    @tag interceptors: [Bamboo.DenyListInterceptor, Bamboo.EnvInterceptor]
    test "deliver_later!/1 must apply interceptors and block email if intercepted" do
      email = new_email(to: "blocked@blocked.com")
      assert %Bamboo.Email{blocked: true} = Mailer.deliver_later!(email)
      refute_receive {:deliver, %Bamboo.Email{to: [{nil, "blocked@blocked.com"}]}, _config}
    end
  end

  defp new_email(attrs \\ []) do
    attrs = Keyword.merge([from: "foo@bar.com", to: "foo@bar.com"], attrs)
    Email.new_email(attrs)
  end
end

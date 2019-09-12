defmodule Bamboo.MailerTest do
  use ExUnit.Case
  alias Bamboo.Email

  @mailer_config adapter: __MODULE__.DefaultAdapter, foo: :bar

  setup context do
    config =
      Keyword.merge(@mailer_config, [adapter: context[:adapter]], fn
        _, v, nil -> v
        _, _, v -> v
      end)

    Application.put_env(:bamboo, __MODULE__.Mailer, config)
    Process.register(self(), :mailer_test)
    on_exit(fn -> Application.delete_env(:bamboo, __MODULE__.Mailer) end)
    :ok
  end

  defmodule(Mailer, do: use(Bamboo.Mailer, otp_app: :bamboo))

  defmodule DefaultAdapter do
    def deliver(email, config), do: send(:mailer_test, {:deliver, email, config})

    def handle_config(config), do: config

    def supports_attachments?, do: true
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

    returned_email = Mailer.deliver_now(email)

    assert returned_email == Bamboo.Mailer.normalize_addresses(email)
    assert_received {:deliver, %Bamboo.Email{}, ^expected_final_config}
  end

  test "deliver/1 raises a helpful error message" do
    assert_raise RuntimeError, ~r/Use deliver_now/, fn ->
      Mailer.deliver(:anything)
    end
  end

  test "deliver_now/1 with no from address raises an error" do
    assert_raise Bamboo.EmptyFromAddressError, fn ->
      Mailer.deliver_now(new_email(from: nil))
    end

    assert_raise Bamboo.EmptyFromAddressError, fn ->
      Mailer.deliver_now(new_email(from: {"foo", nil}))
    end
  end

  test "deliver_now/1 with empty lists for recipients does not deliver email" do
    new_email(to: [], cc: [], bcc: []) |> Mailer.deliver_now()
    refute_received {:deliver, _, _}

    new_email(to: [], cc: nil, bcc: nil) |> Mailer.deliver_now()
    refute_received {:deliver, _, _}

    new_email(to: nil, cc: [], bcc: nil) |> Mailer.deliver_now()
    refute_received {:deliver, _, _}

    new_email(to: nil, cc: nil, bcc: []) |> Mailer.deliver_now()
    refute_received {:deliver, _, _}
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

  test "raises an error if an address does not have a protocol implemented" do
    email = new_email(from: 1)

    assert_raise Protocol.UndefinedError, fn ->
      Mailer.deliver_now(email)
    end
  end

  test "raises if all recipients are nil" do
    assert_raise Bamboo.NilRecipientsError, fn ->
      new_email(to: nil, cc: nil, bcc: nil)
      |> Mailer.deliver_now()
    end

    assert_raise Bamboo.NilRecipientsError, fn ->
      new_email(to: {"foo", nil})
      |> Mailer.deliver_now()
    end

    assert_raise Bamboo.NilRecipientsError, fn ->
      new_email(to: [{"foo", nil}])
      |> Mailer.deliver_now()
    end

    assert_raise Bamboo.NilRecipientsError, fn ->
      new_email(to: [nil])
      |> Mailer.deliver_now()
    end
  end

  test "raises if a map is passed in" do
    email = new_email(from: %{foo: :bar})

    assert_raise ArgumentError, fn ->
      Mailer.deliver_now(email)
    end
  end

  test "raises an error if deliver_now or deliver_later is called directly" do
    email = new_email(from: %{foo: :bar})

    assert_raise RuntimeError, ~r/cannot call Bamboo.Mailer/, fn ->
      Bamboo.Mailer.deliver_now(email)
    end

    assert_raise RuntimeError, ~r/cannot call Bamboo.Mailer/, fn ->
      Bamboo.Mailer.deliver_later(email)
    end
  end

  describe "attachments" do
    defmodule AdapterWithoutAttachmentSupport do
      def deliver(_email, _config), do: :noop

      def handle_config(config), do: config

      def supports_attachments?, do: false
    end

    @tag adapter: AdapterWithoutAttachmentSupport
    test "raise if adapter does not support attachments and attachments are sent" do
      path = Path.join(__DIR__, "../../support/attachment.docx")
      email = new_email(to: "foo@bar.com") |> Email.put_attachment(path)

      assert_raise RuntimeError, ~r/does not support attachments/, fn ->
        Mailer.deliver_now(email)
      end

      assert_raise RuntimeError, ~r/does not support attachments/, fn ->
        Mailer.deliver_later(email)
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

      Mailer.deliver_now(email, config: override_config)

      assert_received {:deliver, _email, config}
      assert config.foo == :qux
      assert config.something == :groovy
    end
  end

  describe "option to return response" do
    defmodule ResponseAdapter do
      def deliver(_email, _config) do
        send(:mailer_test, %{status_code: 202, headers: [%{}], body: ""})
      end

      def handle_config(config), do: config
    end

    @tag adapter: ResponseAdapter
    test "deliver_now/2 returns email and response when passing in response: true option" do
      email = new_email(to: "foo@bar.com")

      {email, response} = Mailer.deliver_now(email, response: true)

      assert %Email{} = email
      assert %{body: _, headers: _, status_code: _} = response
    end

    @tag adapter: ResponseAdapter
    test "deliver_now/1 returns just email when not passing in response: true option" do
      email = new_email(to: "foo@bar.com")

      email = Mailer.deliver_now(email)

      assert %Email{} = email
    end
  end

  defp new_email(attrs \\ []) do
    attrs = Keyword.merge([from: "foo@bar.com", to: "foo@bar.com"], attrs)
    Email.new_email(attrs)
  end
end

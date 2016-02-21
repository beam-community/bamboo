defmodule Bamboo.MailerTest do
  use ExUnit.Case
  alias Bamboo.Email

  defmodule FooAdapter do
    def deliver(email, config) do
      send :mailer_test, {:deliver, email, config}
    end

    def handle_config(config), do: config
  end

  defmodule CustomConfigAdapter do
    def deliver(email, config) do
      send :mailer_test, {:deliver, email, config}
    end

    def handle_config(config) do
      config |> Map.put(:custom_key, "Set by the adapter")
    end
  end

  @custom_config adapter: CustomConfigAdapter, foo: :bar

  Application.put_env(:bamboo, __MODULE__.CustomConfigMailer, @custom_config)

  defmodule CustomConfigMailer do
    use Bamboo.Mailer, otp_app: :bamboo
  end

  @mailer_config adapter: FooAdapter, foo: :bar

  Application.put_env(:bamboo, __MODULE__.FooMailer, @mailer_config)

  defmodule FooMailer do
    use Bamboo.Mailer, otp_app: :bamboo
  end

  setup do
    Process.register(self, :mailer_test)
    :ok
  end

  test "uses adapter's handle_config/1 to customize or validate the config" do
    email = new_email(to: "foo@bar.com")

    CustomConfigMailer.deliver(email)

    assert_received {:deliver, _email, config}
    assert config.custom_key == "Set by the adapter"
  end

  test "sets a default deliver_later_strategy if none is set" do
    email = new_email(to: "foo@bar.com")

    FooMailer.deliver(email)

    assert_received {:deliver, _email, config}
    assert config.deliver_later_strategy == Bamboo.Strategies.TaskSupervisor
  end

  test "deliver/1 calls the adapter with the email and config as a map" do
    email = new_email(to: "foo@bar.com")

    returned_email = FooMailer.deliver(email)

    assert returned_email == Bamboo.Mailer.normalize_addresses(email)
    assert_received {:deliver, %Bamboo.Email{}, config}
    config_with_default_strategy = Enum.into(@mailer_config, %{})
      |> Map.put(:deliver_later_strategy, Bamboo.Strategies.TaskSupervisor)
    assert config == config_with_default_strategy
  end

  test "deliver/1 with no from address" do
    email = new_email(from: nil)

    assert_raise Bamboo.EmptyFromAddressError, fn ->
      FooMailer.deliver(email)
    end
  end

  test "deliver/1 with empty lists for recipients does not deliver email" do
    new_email(to: [], cc: [], bcc: []) |> FooMailer.deliver
    refute_received {:deliver, _, _}

    new_email(to: [], cc: nil, bcc: nil) |> FooMailer.deliver
    refute_received {:deliver, _, _}

    new_email(to: nil, cc: [], bcc: nil) |> FooMailer.deliver
    refute_received {:deliver, _, _}

    new_email(to: nil, cc: nil, bcc: []) |> FooMailer.deliver
    refute_received {:deliver, _, _}
  end

  test "deliver_later/1 with empty lists for recipients does not deliver email" do
    new_email(to: [], cc: [], bcc: []) |> FooMailer.deliver_later
    refute_received {:deliver, _, _}

    new_email(to: [], cc: nil, bcc: nil) |> FooMailer.deliver_later
    refute_received {:deliver, _, _}

    new_email(to: nil, cc: [], bcc: nil) |> FooMailer.deliver_later
    refute_received {:deliver, _, _}

    new_email(to: nil, cc: nil, bcc: []) |> FooMailer.deliver_later
    refute_received {:deliver, _, _}
  end

  test "deliver_later/1 calls deliver on the adapter" do
    email = new_email

    FooMailer.deliver_later(email)

    assert_receive {:deliver, delivered_email, _config}
    assert delivered_email == Bamboo.Mailer.normalize_addresses(email)
  end

  test "deliver/1 wraps the recipients in a list" do
    address = {"Someone", "foo@bar.com"}
    email = new_email(to: address, cc: address, bcc: address)

    FooMailer.deliver(email)

    assert_received {:deliver, delivered_email, _}
    assert delivered_email.to == [address]
    assert delivered_email.cc == [address]
    assert delivered_email.bcc == [address]
  end

  test "deliver/1 converts binary addresses to %{name: name, email: email}" do
    address = "foo@bar.com"
    email = new_email(from: address, to: address, cc: address, bcc: address)

    FooMailer.deliver(email)

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

    FooMailer.deliver(email)

    converted_recipient = {user.first_name, user.email}
    assert_received {:deliver, delivered_email, _}
    assert delivered_email.from == {"#{user.first_name} (MyApp)", user.email}
    assert delivered_email.to == [converted_recipient]
    assert delivered_email.cc == [converted_recipient]
    assert delivered_email.bcc == [converted_recipient]
  end

  test "raises an error if an address does not have a protocol implemented" do
    email = new_email(from: 1)

    assert_raise Protocol.UndefinedError, fn ->
      FooMailer.deliver(email)
    end
  end

  test "raises if all receipients are nil" do
    assert_raise Bamboo.NilRecipientsError, fn ->
      new_email(to: nil, cc: nil, bcc: nil) |> FooMailer.deliver
    end
  end

  test "raises if a map is passed in" do
    email = new_email(from: %{foo: :bar})

    assert_raise ArgumentError, fn ->
      FooMailer.deliver(email)
    end
  end

  defp new_email(attrs \\ []) do
    attrs = Keyword.merge([from: "foo@bar.com", to: "foo@bar.com"], attrs)
    Email.new_email(attrs)
  end
end

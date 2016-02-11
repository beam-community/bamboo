defmodule Bamboo.MailerTest do
  use ExUnit.Case

  alias Bamboo.Email
  alias Bamboo.EmailAddress

  defmodule FooAdapter do
    def deliver(email, config) do
      send :test, {:deliver, email, config}
    end

    def deliver_later(email, config) do
      send :test, {:deliver_later, email, config}
    end
  end

  @mailer_config adapter: FooAdapter, foo: :bar

  Application.put_env(:bamboo, __MODULE__.FooMailer, @mailer_config)

  defmodule FooMailer do
    use Bamboo.Mailer, otp_app: :bamboo
  end

  setup do
    Process.register(self, :test)
    :ok
  end

  test "deliver/1 calls the adapter with the email and config" do
    FooMailer.deliver(new_email)

    assert_received {:deliver, %Bamboo.Email{}, @mailer_config}
  end

  test "deliver/1 with no from address" do
    email = new_email(from: nil)

    assert_raise Bamboo.EmptyFromAddressError, fn ->
      FooMailer.deliver(email)
    end
  end

  test "deliver_later/1 calls deliver_later on the adapter" do
    email = new_email

    FooMailer.deliver_later(email)

    assert_receive {:deliver_later, delivered_email, config}
    assert config == @mailer_config
    assert delivered_email == Bamboo.Mailer.normalize_addresses(email)
  end

  test "deliver/1 wraps the recipients in a list" do
    address = %EmailAddress{name: "Someone", address: "foo@bar.com"}
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

    converted_address = %EmailAddress{name: nil, address: address}
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

    converted_recipient = %EmailAddress{name: user.first_name, address: user.email}
    assert_received {:deliver, delivered_email, _}
    assert delivered_email.from == %EmailAddress{
      name: "#{user.first_name} (MyApp)",
      address: user.email
    }
    assert delivered_email.to == [converted_recipient]
    assert delivered_email.cc == [converted_recipient]
    assert delivered_email.bcc == [converted_recipient]
  end

  test "raises an error if an address does not have a protocol implemented" do
    email = new_email(from: [foo: :bar])

    assert_raise Protocol.UndefinedError, fn ->
      FooMailer.deliver(email)
    end
  end

  test "raises an error if a map is passed in an not a Bamboo.EmailAddress" do
    email = new_email(from: %{foo: :bar})

    assert_raise ArgumentError, fn ->
      FooMailer.deliver(email)
    end
  end

  defp new_email(attrs \\ []) do
    attrs = Keyword.merge([from: "foo@bar.com"], attrs)
    Email.new_email(attrs)
  end
end

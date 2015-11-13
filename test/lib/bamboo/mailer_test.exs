defmodule Bamboo.MailerTest do
  use ExUnit.Case

  import Bamboo.Email, only: [new_email: 0, new_email: 1]

  defmodule FooAdapter do
    def deliver(email, config) do
      send :test, {:deliver, email, config}
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

  test "deliver/1 a nil `from` is still converted" do
    email = new_email(from: nil)

    FooMailer.deliver(email)

    assert_received {:deliver, delivered_email, _}
    assert delivered_email.from == %{name: nil, address: nil}
  end

  test "deliver_async/1 calls the regular deliver method asynchronously" do
    email = new_email

    FooMailer.deliver_async(email)

    assert_receive {:deliver, delivered_email, _}
    assert delivered_email == Bamboo.Mailer.normalize_addresses(email)
  end

  test "deliver_async/1 returns a Task that can be awaited on" do
    email = new_email

    task = FooMailer.deliver_async(email)

    Task.await(task)
    assert_received {:deliver, delivered_email, _}
    assert delivered_email == Bamboo.Mailer.normalize_addresses(email)
  end

  test "deliver/1 wraps the recipients in a list" do
    address = %{name: "Someone", address: "foo@bar.com"}
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

    converted_address = %{name: nil, address: address}
    assert_received {:deliver, delivered_email, _}
    assert delivered_email.from == converted_address
    assert delivered_email.to == [converted_address]
    assert delivered_email.cc == [converted_address]
    assert delivered_email.bcc == [converted_address]
  end

  test "raises an error if an address is not in a correct format" do
    email = new_email(from: [foo: :bar])

    assert_raise ArgumentError, fn ->
      FooMailer.deliver(email)
    end
  end
end

defmodule Bamboo.Test do
  defmacro __using__(_opts) do
    quote do
      import Bamboo.Formatter, only: [format_email_address: 2]
      import Bamboo.Test
    end
  end

  def assert_delivered_email(email) do
    import ExUnit.Assertions
    email = Bamboo.Mailer.normalize_addresses(email)
    assert_received {:delivered_email, ^email}
  end

  def refute_delivered_email(email) do
    import ExUnit.Assertions
    email = Bamboo.Mailer.normalize_addresses(email)
    refute_received {:delivered_email, ^email}
  end
end

defmodule Bamboo.TestAdapterTest do
  use ExUnit.Case

  import Bamboo.Email, only: [new_email: 0, new_email: 1]
  alias Bamboo.TestMailbox

  @mailer_config adapter: Bamboo.TestAdapter

  Application.put_env(:bamboo, __MODULE__.TestMailer, @mailer_config)

  defmodule TestMailer do
    use Bamboo.Mailer, otp_app: :bamboo
  end

  setup do
    TestMailbox.reset
  end

  test "deliveries contains emails that have been delivered" do
    email = new_normalized_email(subject: "This is my email")

    email |> TestMailer.deliver

    assert TestMailbox.deliveries == [email]
  end

  defp new_normalized_email(attrs) do
    new_email(attrs) |> Bamboo.Mailer.normalize_addresses
  end
end

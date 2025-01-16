defmodule Bamboo.ImmediateDeliveryStrategyTest do
  use ExUnit.Case

  @mailer_config %{}

  defmodule FakeAdapter do
    def deliver(_email, _config), do: send(self(), :delivered)
  end

  test "deliver_later delivers right away" do
    Bamboo.ImmediateDeliveryStrategy.deliver_later(
      FakeAdapter,
      Bamboo.Email.new_email(),
      @mailer_config
    )

    assert_received :delivered
  end
end

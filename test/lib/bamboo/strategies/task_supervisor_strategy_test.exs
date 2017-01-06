defmodule Bamboo.TaskSupervisorStrategyTest do
  use ExUnit.Case

  defmodule FakeAdapter do
    def deliver(_email, _config) do
      send :task_supervisor_strategy_test, :delivered
    end
  end

  @mailer_config %{}

  test "deliver_later delivers the email" do
    Process.register(self(), :task_supervisor_strategy_test)

    Bamboo.TaskSupervisorStrategy.deliver_later(
      FakeAdapter,
      Bamboo.Email.new_email,
      @mailer_config
    )

    assert_receive :delivered
  end

  test "child_spec raises error about removal" do
    assert_raise RuntimeError, ~r/Bamboo.TaskSupervisorStrategy.child_spec/, fn ->
      Bamboo.TaskSupervisorStrategy.child_spec
    end
  end
end

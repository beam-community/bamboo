defmodule Bamboo.TaskSupervisorStrategyTest do
  use ExUnit.Case

  defmodule FakeAdapter do
    def deliver(_email, _config) do
      send(:task_supervisor_strategy_test, :delivered)
      {:ok, "response"}
    end
  end

  defmodule FailureAdapter do
    def deliver(_email, _config) do
      {:error, "an error happened"}
    end
  end

  @mailer_config %{}

  test "deliver_later delivers the email" do
    Process.register(self(), :task_supervisor_strategy_test)

    Bamboo.TaskSupervisorStrategy.deliver_later(
      FakeAdapter,
      Bamboo.Email.new_email(),
      @mailer_config
    )

    assert_receive :delivered
  end

  @tag :capture_log
  test "raises error if adapter returns error" do
    Process.register(self(), :task_supervisor_strategy_test)

    {:ok, pid} =
      Bamboo.TaskSupervisorStrategy.deliver_later(
        FailureAdapter,
        Bamboo.Email.new_email(),
        @mailer_config
      )

    ref = Process.monitor(pid)

    assert_receive {:DOWN, ^ref, :process, _, error}
    assert %RuntimeError{message: "an error happened"} = elem(error, 0)
    refute_receive :delivered
  end
end

defmodule Bamboo.AdapterHelperTest do
  use ExUnit.Case

  describe "hackney_opts" do
    test "when no hackney_opts key exists in config" do
      assert Bamboo.AdapterHelper.hackney_opts(%{}) == [
               :with_body
             ]
    end

    test "adds [:with_body] to hackney opts from config" do
      config = %{
        hackney_opts: [
          recv_timeout: :timer.minutes(1),
          connect_timeout: :timer.minutes(1)
        ]
      }

      assert Bamboo.AdapterHelper.hackney_opts(config) == [
               {:recv_timeout, 60_000},
               {:connect_timeout, 60_000},
               :with_body
             ]
    end
  end
end

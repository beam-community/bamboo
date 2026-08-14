defmodule Bamboo.AdapterHelperTest do
  use ExUnit.Case

  describe "req_options" do
    test "when no req_opts key exists in config" do
      assert Bamboo.AdapterHelper.req_options(%{}) == [
               decode_body: false
             ]
    end

    test "adds [decode_body: false] to req opts from config" do
      config = %{
        req_opts: [
          receive_timeout: 60_000,
          connect_options: [timeout: 60_000]
        ]
      }

      assert Bamboo.AdapterHelper.req_options(config) == [
               receive_timeout: 60_000,
               connect_options: [timeout: 60_000],
               decode_body: false
             ]
    end
  end
end

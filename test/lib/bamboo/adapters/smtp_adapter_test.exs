defmodule Bamboo.SMTPAdapterTest do
  use ExUnit.Case
  alias Bamboo.SMTPAdapter

  @configuration %{
    adapter: SMTPAdapter,
    server: "smtp.domain",
    port: 1025,
    username: "your.name@your.domain",
    password: "pa55word"
  }

  test "raises if the server is nil" do
    assert_raise ArgumentError, ~r/Key server is required/, fn ->
      SMTPAdapter.handle_config(configuration(%{server: nil}))
    end
  end

  test "raises if the port is nil" do
    assert_raise ArgumentError, ~r/Key port is required/, fn ->
      SMTPAdapter.handle_config(configuration(%{port: nil}))
    end
  end

  test "raises if the username is nil" do
    assert_raise ArgumentError, ~r/Key username is required/, fn ->
      SMTPAdapter.handle_config(configuration(%{username: nil}))
    end
  end

  test "raises if the password is nil" do
    assert_raise ArgumentError, ~r/Key password is required/, fn ->
      SMTPAdapter.handle_config(configuration(%{password: nil}))
    end
  end

  test "sets default tls key if not present" do
    %{tls: tls} = SMTPAdapter.handle_config(configuration)

    assert :if_available == tls
  end

  test "doesn't set a default tls key if present" do
    %{tls: tls} = SMTPAdapter.handle_config(configuration(%{tls: :always}))

    assert :always == tls
  end

  test "sets default ssl key if not present" do
    %{ssl: ssl} = SMTPAdapter.handle_config(configuration)

    refute ssl
  end

  test "doesn't set a default ssl key if present" do
    %{ssl: ssl} = SMTPAdapter.handle_config(configuration(%{ssl: true}))

    assert ssl
  end

  test "sets default retries key if not present" do
    %{retries: retries} = SMTPAdapter.handle_config(configuration)

    assert retries == 1
  end

  test "doesn't set a default retries key if present" do
    %{retries: retries} = SMTPAdapter.handle_config(configuration(%{retries: 42}))

    assert retries == 42
  end

  defp configuration, do: @configuration
  defp configuration(override), do: Map.merge(configuration, override)
end

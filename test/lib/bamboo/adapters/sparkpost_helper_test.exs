defmodule Bamboo.SparkpostHelperTest do
  use ExUnit.Case
  import Bamboo.Email
  alias Bamboo.SparkpostHelper

  test "adds tags to sparkpost emails" do
    email = new_email |> SparkpostHelper.tag("welcome-email")
    assert email.private.message_params == %{tags: ["welcome-email"]}

    email = new_email |> SparkpostHelper.tag(["welcome-email", "awesome"])
    assert email.private.message_params == %{tags: ["welcome-email", "awesome"]}

    email = new_email |> SparkpostHelper.tag(["welcome-email"]) |> SparkpostHelper.tag(["awesome"]) |> SparkpostHelper.tag("another")
    assert email.private.message_params == %{tags: ["welcome-email", "awesome", "another"]}
  end

  test "it marks the email as transactional" do
    email = new_email |> SparkpostHelper.mark_transactional
    assert email.private.message_params == %{options: %{transactional: true}}
  end

  test "it adds meta data" do
    email = new_email |> SparkpostHelper.meta_data(foo: "bar")
    assert email.private.message_params == %{metadata: %{foo: "bar"}}

    email = new_email |> SparkpostHelper.meta_data(%{foo: "bar"})
    assert email.private.message_params == %{metadata: %{foo: "bar"}}
  end

  test "it merges meta data" do
    email = new_email |> SparkpostHelper.meta_data(foo: "bar") |> SparkpostHelper.meta_data(%{bar: "baz"})
    assert email.private.message_params == %{metadata: %{foo: "bar", bar: "baz"}}
  end

  test "it tracks opens" do
    email = new_email |> SparkpostHelper.track_opens
    assert email.private.message_params == %{options: %{open_tracking: true}}
  end

  test "it tracks clicks" do
    email = new_email |> SparkpostHelper.track_clicks
    assert email.private.message_params == %{options: %{click_tracking: true}}
  end

  test "put it all together" do
    email = new_email
    |> SparkpostHelper.track_clicks
    |> SparkpostHelper.track_opens
    |> SparkpostHelper.mark_transactional
    |> SparkpostHelper.tag(["foo", "bar"])
    |> SparkpostHelper.meta_data(foo: "bar")

    assert email.private.message_params == %{
      options: %{open_tracking: true, transactional: true, click_tracking: true},
      metadata: %{foo: "bar"},
      tags: ["foo", "bar"]
    }
  end
end

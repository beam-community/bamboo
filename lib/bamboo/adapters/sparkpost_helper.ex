defmodule Bamboo.SparkpostHelper do
  @moduledoc """
  Functions for using features specific to Sparkpost e.g. tagging
  """

  alias Bamboo.Email

  @doc """
  Put extra message parameters that are used by Sparkpost

  Parameters set with this function are sent to Sparkpost when used along with
  the Bamboo.SparkpostAdapter. You can set things like `important`, `merge_vars`,
  and whatever else you need that the Sparkpost API supports.

  ## Example

      email
      |> put_param([:options, :open_tracking], true)
      |> put_param(:tags, ["foo", "bar"])
      |> put_param(:meta_data, %{foo: "bar"})
  """
  def put_param(email, keys, value) do
    keys = List.wrap(keys)
    message_params = (email.private[:message_params] || %{})
    |> ensure_keys(keys)
    |> update_value(keys, value)

    email
    |> Email.put_private(:message_params, message_params)
  end

  @doc """
  Set a single tag or multiple tags for an email.

  ## Example

      tag(email, "welcome-email")
      tag(email, ["welcome-email", "marketing"])
  """
  def tag(email, tags) do
    put_param(email, :tags, List.wrap(tags))
  end

  @doc ~S"""
  Add meta data to an email

  ## Example

     email
     |> meta_data(foo: bar)
     |> meta_data(%{bar: "baz")
  """
  def meta_data(email, map) when is_map(map) do
    put_param(email, :metadata, map)
  end
  def meta_data(email, map) do
    put_param(email, :metadata, Enum.into(map, %{}))
  end

  @doc ~S"""
  Mark an email as transactional

  ## Example
      email |> mark_transactional
  """
  def mark_transactional(email) do
    put_param(email, [:options, :transactional], true)
  end

  @doc ~S"""
  Enable open tracking

  ## Example
      email |> track_opens
  """
  def track_opens(email) do
    put_param(email, [:options, :open_tracking], true)
  end

  @doc ~S"""
  Enable click tracking

  ## Example
      email |> track_clicks
  """
  def track_clicks(email) do
    put_param(email, [:options, :click_tracking], true)
  end

  defp update_value(map, keys, value) when is_list(value) do
    map
    |> update_in(keys, fn
      nil -> value
      val -> val ++ value
    end)
  end
  defp update_value(map, keys, value) when is_map(value) do
    map
    |> update_in(keys, fn
      nil -> value
      val -> Map.merge(val, value)
    end)
  end
  defp update_value(map, keys, value) do
    map
    |> put_in(keys, value)
  end

  defp ensure_keys(map, [key]) do
    Map.update(map, key, nil, fn(value) -> value end)
  end
  defp ensure_keys(map, [key | tail]) do
    Map.update(map, key, ensure_keys(%{}, tail), fn(value) -> ensure_keys(value, tail) end)
  end
  defp ensure_keys(map, key), do: ensure_keys(map, [key])
end

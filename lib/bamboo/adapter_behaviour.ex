defmodule Bamboo.Adapter do
  @callback deliver(%Bamboo.Email{}, %{}) :: any
  @callback deliver_async(%Bamboo.Email{}, %{}) :: Task.t
end

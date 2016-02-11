defmodule Bamboo.Adapter do
  @moduledoc """
  Use this behaviour when creating adapters to be used by Bamboo.

  Accepts an email, and the config that was set for the mailer.

  ## Example

      defmodule Bamboo.CustomAdapter do
        @behaviour Bamboo.Adapter

        def deliver(email, config) do
          deliver_the_email_somehow(email)
        end

        def deliver_later(email, config) do
          # You could also add the email to a GenServer or ExQ for delivery.
          Task.async fn ->
            Bamboo.CustomAdapter.deliver(email, config)
          end
        end
      end
  """

  @callback deliver(%Bamboo.Email{}, %{}) :: any
  @callback deliver_later(%Bamboo.Email{}, %{}) :: Task.t
end

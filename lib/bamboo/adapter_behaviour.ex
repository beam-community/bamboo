defmodule Bamboo.Adapter do
  @moduledoc ~S"""
  Behaviour for creating Bamboo adapters

  All recipients in the Bamboo.Email struct will be normalized to a 2 item tuple
  of {name, address}. For example, `email.from |> elem(0)` would return the name
  and `email.from |> elem(1)` would return the email address.

  ## Example

      defmodule Bamboo.CustomAdapter do
        @behaviour Bamboo.Adapter

        def deliver(email, config) do
          deliver_the_email_somehow(email)
        end

        def handle_config(config) do
          # Return the config if nothing special is required
          config

          # Or you could require certain config options
          if Map.get(config, :smtp_username) do
            config
          else
            raise "smpt_username is required in config, got #{inspect config}"
          end
        end
      end
  """

  @callback deliver(%Bamboo.Email{}, %{}) :: any
  @callback handle_config(map) :: map
end

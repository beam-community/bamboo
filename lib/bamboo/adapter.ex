defmodule Bamboo.Adapter do
  @moduledoc ~S"""
  Behaviour for creating Bamboo adapters

  All recipients in the Bamboo.Email struct will be normalized to a 2 item tuple
  of {name, address} when deliver through your mailer. For example,
  `email.from |> elem(0)` would return the name and `email.from |> elem(1)`
  would return the email address.

  For more in-depth examples check out the
  [adapters in Bamboo](https://github.com/paulcsmith/bamboo/tree/master/lib/bamboo/adapters).

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
            raise "smtp_username is required in config, got #{inspect config}"
          end
        end
      end
  """

  @type response :: Bamboo.Response.t
  @callback deliver(%Bamboo.Email{}, %{}) :: response
  @callback handle_config(map) :: map
end

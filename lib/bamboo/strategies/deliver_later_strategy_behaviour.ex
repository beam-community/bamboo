defmodule Bamboo.DeliverLaterStrategy do
  @moduledoc """
  Behaviour when creating strategies for delivering emails with deliver_later

  Use this behaviour to create strategies for delivering later. You could make a
  strategy using a GenServer, a backgrund job library or whatever else you
  decide. Bamboo ships with two strategies:
  [Bamboo.TaskSupervisorStrategy](Bamboo.TaskSupervisorStrategy.html) and
  [Bamboo.DeliverImmediatelyStrategy](Bamboo.DeliverImmediatelyStrategy)

  ## Example of setting custom strategies

      config :my_app, MyApp.Mailer,
        adapter: Bamboo.MandrillAdapter, # or whatever adapter you want
        deliver_later_strategy: MyCustomStrategy

  ## Example of delivery using Task.async

      defmodule Bamboo.MyCustomStrategy do
        @behaviour Bamboo.DeliverLaterStrategy

        # This is a strategy for delivering later using Task.async
        def deliver_later(adapter, email, config) do
          Task.async fn ->
            # Always call deliver on the adapter so that the email is delivered.
            adapter.deliver(email, config)
          end
        end
      end
  """

  @callback deliver_later(atom, %Bamboo.Email{}, map) :: any
end

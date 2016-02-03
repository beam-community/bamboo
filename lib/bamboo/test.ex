defmodule Bamboo.Test do
  defmacro __using__(_opts) do
    quote do
      alias Bamboo.SentEmail
      import Bamboo.Formatter, only: [format_email_address: 1]

      setup do
        SentEmail.reset
        :ok
      end
    end
  end
end

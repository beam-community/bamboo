defmodule Bamboo.Test do
  defmacro __using__(_opts) do
    quote do
      alias Bamboo.SentEmail
      import Bamboo.Formatter, only: [format_recipient: 1]

      setup do
        SentEmail.reset
        :ok
      end
    end
  end
end

defmodule Bamboo.Interceptor do
  @callback call(email :: Bamboo.Email.t()) :: Bamboo.Email.t() | :intercepted

  defmacro __using__(_) do
    quote do
      @behaviour Bamboo.Interceptor
      def call(:intercepted), do: :intercepted
    end
  end
end

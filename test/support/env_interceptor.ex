defmodule Bamboo.EnvInterceptor do
  @behaviour Bamboo.Interceptor

  @env Mix.env()

  def call(email) do
    %{email | subject: "#{@env} - #{email.subject}"}
  end
end

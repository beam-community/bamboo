defmodule Bamboo.EnvInterceptor do
  use Bamboo.Interceptor

  @env Mix.env()

  def call(email) do
    %{email | subject: "#{@env} - #{email.subject}"}
  end
end

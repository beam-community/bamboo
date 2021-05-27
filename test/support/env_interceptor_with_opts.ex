defmodule Bamboo.EnvInterceptorWithOpts do
  @behaviour Bamboo.Interceptor

  @impl true
  def call(email, opts) do
    %{email | subject: "#{Keyword.fetch!(opts, :env)} - #{email.subject}"}
  end
end

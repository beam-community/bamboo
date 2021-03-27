defmodule Bamboo.DenyListInterceptor do
  @behaviour Bamboo.Interceptor

  @deny_list ["blocked@blocked.com"]

  def call(email) do
    if Enum.any?(email.to, &(elem(&1, 1) in @deny_list)) do
      Bamboo.Email.intercept(email)
    else
      email
    end
  end
end

defmodule Bamboo.DenyListInterceptor do
  @behaviour Bamboo.Interceptor

  @deny_list ["blocked@blocked.com"]

  def call(email) do
    if email.to in @deny_list do
      Bamboo.Email.intercept(email)
    else
      email
    end
  end
end

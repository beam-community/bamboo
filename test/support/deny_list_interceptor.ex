defmodule Bamboo.DenyListInterceptor do
  @behaviour Bamboo.Interceptor

  @deny_list ["blocked@blocked.com"]

  def call(%{to: recipients} = email) when is_list(recipients) do
    if Enum.any?(recipients, &(&1 in @deny_list)) do
      Bamboo.Email.block(email)
    else
      email
    end
  end

  def call(%{to: recipient} = email) when recipient in @deny_list do
    Bamboo.Email.block(email)
  end

  def call(email) do
    email
  end
end

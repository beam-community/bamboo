defmodule Bamboo.BlackListInterceptor do
  use Bamboo.Interceptor

  @black_list ["bar@foo.com"]

  def call(email) do
    if email.to in @black_list do
      :intercepted
    else
      email
    end
  end
end

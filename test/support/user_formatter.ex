defmodule Bamboo.Test.User do
  defstruct first_name: "", email: ""
end

defimpl Bamboo.Formatter, for: Bamboo.Test.User do
  def format_email_address(user, %{type: :from}) do
    {"#{user.first_name} (MyApp)", user.email}
  end

  def format_email_address(user, _opts) do
    {user.first_name, user.email}
  end
end

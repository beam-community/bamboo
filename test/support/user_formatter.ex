defmodule Bamboo.Test.User do
  defstruct first_name: "", email: ""
end

defimpl Bamboo.Formatter, for: Bamboo.Test.User do
  def format_recipient(user) do
    %{name: user.first_name, address: user.email}
  end
end

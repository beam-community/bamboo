defmodule Bamboo.Test.User do
  defstruct first_name: "", email: ""
end

defimpl Bamboo.Formatter, for: Bamboo.Test.User do
  def format_email_address(user) do
    %Bamboo.EmailAddress{name: user.first_name, address: user.email}
  end
end

defmodule Bamboo.Test.User do
  defstruct first_name: "", email: ""
end

defimpl Bamboo.Formatter, for: Bamboo.Test.User do
  def format_email_address(user, %{type: :from}) do
    %Bamboo.EmailAddress{name: "#{user.first_name} (MyApp)", address: user.email}
  end

  def format_email_address(user, _opts) do
    %Bamboo.EmailAddress{name: user.first_name, address: user.email}
  end
end

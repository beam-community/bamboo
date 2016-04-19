defmodule Bamboo.Factory do
  use ExMachina
  use Bamboo.NormalizeAndPushStrategy

  def factory(:email) do
    %Bamboo.Email{
      from: sequence(:email, &"from-#{&1}@gmail.com"),
      subject: sequence("Email subject")
    }
  end
end

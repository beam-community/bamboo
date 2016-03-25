defmodule Bamboo.Factory do
  use ExMachina
  use Bamboo.NormalizeAndPushStrategy

  def factory(:email) do
    %Bamboo.Email{
      from: "from@gmail.com",
      subject: sequence("Email subject")
    }
  end
end

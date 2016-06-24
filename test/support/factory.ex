defmodule Bamboo.Factory do
  use ExMachina
  use Bamboo.NormalizeAndPushStrategy

  def email_factory do
    %Bamboo.Email{
      from: sequence(:email, &"from-#{&1}@gmail.com"),
      subject: sequence("Email subject")
    }
  end

  def html_email_factory do
    %Bamboo.Email{
      from: sequence(:email, &"from-#{&1}@gmail.com"),
      subject: sequence("Email subject"),
      html_body: "<p>ohai!</p>"
    }
  end
end

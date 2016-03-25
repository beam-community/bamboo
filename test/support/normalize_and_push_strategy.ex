defmodule Bamboo.NormalizeAndPushStrategy do
  use ExMachina.Strategy, function_name: :normalize_and_push

  def handle_normalize_and_push(email, _opts) do
    email |> Bamboo.Mailer.normalize_addresses |> Bamboo.SentEmail.push
  end
end

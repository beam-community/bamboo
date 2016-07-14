defmodule Bamboo.SendgridAdapter do
  @moduledoc false

  def deliver(_email, _config) do
    raise """
    Bamboo.SendgridAdapter has been renamed to SendGridAdapter (note the capital "G")

    Please use Bamboo.SendGridAdapter (with a capital "G") in your config. This was changed to       
    correctly match how SendGrid is spelled.
    """
  end
end

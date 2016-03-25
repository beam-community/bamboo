defmodule Bamboo.EmailPreviewPlug.Helper do
  import Bamboo.SentEmail

  def selected_email_class(email, selected_email) do
    if get_id(email) == get_id(selected_email) do
      "selected-email"
    else
      ""
    end
  end

  def email_addresses(email) do
    Bamboo.Email.all_recipients(email)
    |> Enum.map(&Bamboo.Email.get_address/1)
    |> Enum.join(", ")
  end

  def format_text(nil), do: ""
  def format_text(text_body) do
    String.replace(text_body, "\n", "<br>")
  end
end

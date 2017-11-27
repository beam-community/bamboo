defmodule Bamboo.SentEmailViewerPlug.Helper do
  import Bamboo.SentEmail

  @moduledoc false

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

  def format_headers(values) when is_binary(values), do: values
  def format_headers(values) when is_list(values) do
    Enum.join(values, ", ")
  end
  def format_headers(values), do: inspect(values)

  def format_text(nil), do: ""
  def format_text(text_body) do
    String.replace(text_body, "\n", "<br>")
  end

  def format_email_address({nil, address}), do: address
  def format_email_address({name, address}) do
    "#{name}&lt;#{address}&gt;"
  end
end

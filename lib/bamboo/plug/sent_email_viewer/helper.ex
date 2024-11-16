defmodule Bamboo.SentEmailViewerPlug.Helper do
  @moduledoc false

  import Bamboo.SentEmail

  alias Plug.HTML

  def selected_email_class(email, selected_email) do
    if get_id(email) == get_id(selected_email) do
      "selected-email"
    else
      ""
    end
  end

  def email_addresses(email) do
    email
    |> Bamboo.Email.all_recipients()
    |> Enum.map_join(", ", &format_email_address/1)
  end

  def format_headers(values) when is_binary(values) do
    HTML.html_escape(values)
  end

  def format_headers(values) when is_list(values) do
    values
    |> Enum.join(", ")
    |> HTML.html_escape()
  end

  def format_headers(values) do
    values
    |> inspect()
    |> HTML.html_escape()
  end

  def format_subject(subject) do
    HTML.html_escape(subject || "")
  end

  def format_text_body(body) do
    HTML.html_escape(body || "")
  end

  def format_email_address(emails) when is_list(emails),
    do: Enum.map(emails, &format_email_address/1)

  def format_email_address({nil, address}), do: address

  def format_email_address({name, address}) do
    "#{name} &lt;#{address}&gt;"
  end

  def format_attachment(%{filename: filename}) do
    HTML.html_escape(filename)
  end
end

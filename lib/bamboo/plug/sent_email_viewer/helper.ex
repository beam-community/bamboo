defmodule Bamboo.SentEmailViewerPlug.Helper do
  import Bamboo.SentEmail
  alias Plug.HTML

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

  def format_email_address({nil, address}), do: address

  def format_email_address({name, address}) do
    "#{name}&lt;#{address}&gt;"
  end

  def format_json_email(email) do
    email
    |> Map.update(:from, nil, &format_json_email_address/1)
    |> Map.take([:to, :cc, :bcc, :subject, :text_body, :html_body, :headers, :attachments])
  end

  defp format_json_email_address({name, address}) do
    [name, address]
  end
end

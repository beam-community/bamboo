defmodule Bamboo.SendGridHelper do
  @moduledoc """
  Functions for using features specific to Sendgrid.

  ## Example

      email
      |> with_template("80509523-83de-42b6-a2bf-54b7513bd2aa")
      |> substitute("%name%", "Jon Snow")
      |> substitute("%location%", "Westeros")
  """

  alias Bamboo.Email

  @id_size 36
  @field_name "x-smtpapi"

  @doc """
  Specify the template for SendGrid to use for the context of the substitution
  tags.

  ## Example

      email
      |> with_template("80509523-83de-42b6-a2bf-54b7513bd2aa")
  """
  def with_template(email, template_id) do
    if byte_size(template_id) == @id_size do
      xsmtpapi = Map.get(email.private, @field_name, %{})
      email
      |> Email.put_private(@field_name, set_template(xsmtpapi, template_id))
    else
      raise "expected the template_id parameter to be a UUID 36 characters long, got #{template_id}"
    end
  end

  @doc """
  Add a tag to the list of substitutions in the SendGrid template.

  The tag must be a `String.t` due to SendGrid using special characters to wrap
  tags in the template.

  ## Example

      email
      |> substitute("%name%", "Jon Snow")
  """
  def substitute(email, tag, value) do
    if is_binary(tag) do
      xsmtpapi = Map.get(email.private, @field_name, %{})
      email
      |> Email.put_private(@field_name, add_subsitution(xsmtpapi, tag, value))
    else
      raise "expected the tag parameter to be of type binary, got #{tag}"
    end
  end

  defp set_template(xsmtpapi, template_id) do
    xsmtpapi
    |> Map.merge(%{"filters" => build_template_filter(template_id)})
  end

  defp add_subsitution(xsmtpapi, tag, value) do
    xsmtpapi
    |> Map.update("sub", %{tag => [value]}, fn substitutions ->
      Map.merge(substitutions, %{tag => [value]})
    end)
  end

  defp build_template_filter(template_id) do
    %{
      "templates" => %{
        "settings" => %{
          "enable" => 1,
          "template_id" => template_id
        }
      }
    }
  end
end

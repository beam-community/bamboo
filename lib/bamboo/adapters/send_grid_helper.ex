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
  @field_name :send_grid_template
  @custom_args :custom_args

  @doc """
  Specify a custom argument values that are specific to the entire send that will be carried along with the email and its activity data.
  Substitutions are not made on custom arguments within SendGrid.
  The combined total size of these custom arguments may not exceed 10,000 bytes.

  ## Example

      email
      |> with_custom_args("userId", "12345")
  """
  def with_custom_args(email, arg_name, arg_value) do
    custom_args = Map.get(email.private, @custom_args, %{})
    |> Map.put(arg_name, arg_value)
    email
    |> Email.put_private(@custom_args, custom_args)
  end

  @doc """
  Specify the template for SendGrid to use for the context of the substitution
  tags.

  ## Example

      email
      |> with_template("80509523-83de-42b6-a2bf-54b7513bd2aa")
  """
  def with_template(email, template_id) do
    if byte_size(template_id) == @id_size do
      template = Map.get(email.private, @field_name, %{})
      email
      |> Email.put_private(@field_name, set_template(template, template_id))
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
      template = Map.get(email.private, @field_name, %{})
      email
      |> Email.put_private(@field_name, add_substitution(template, tag, value))
    else
      raise "expected the tag parameter to be of type binary, got #{tag}"
    end
  end

  defp set_template(template, template_id) do
    template
    |> Map.merge(%{template_id: template_id})
  end

  defp add_substitution(template, tag, value) do
    template
    |> Map.update(:substitutions, %{tag => [value]}, fn substitutions ->
      Map.merge(substitutions, %{tag => [value]})
    end)
  end
end

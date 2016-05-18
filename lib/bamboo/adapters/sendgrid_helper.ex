defmodule Bamboo.SendgridHelper do
  @moduledoc """
  Functions for using features specific to Sendgrid template substitution tags.

  Only one template can be specified, but multiple tags can be added to the
  email. Ordering of the function calls do not make a difference.

  ## Example

      email
      |> with_template("80509523-83de-42b6-a2bf-54b7513bd2aa")
      |> substitute("%name%", "Jon Snow")
      |> substitute("%location%", "Westeros")
  """

  alias Bamboo.Email

  @id_size 36

  @doc """
  Specify the template for SendGrid to use for the substitutions

  The `template_id` must be a valid `UUID` as generated for each template by
  SendGrid. If called multiple times, the last template specified will be used.

  ## Example

      email
      |> with_template("80509523-83de-42b6-a2bf-54b7513bd2aa")
  """
  def with_template(%Email{private: %{"x-smtpapi" => _}} = email, template_id) when byte_size(template_id) == @id_size do
    fields = email.private["x-smtpapi"]
             |> Map.merge(%{"filters" => build_template_filter(template_id)})

    email |> Email.put_private("x-smtpapi", fields)
  end

  def with_template(email, template_id) when byte_size(template_id) == @id_size do
    email |> Email.put_private("x-smtpapi", %{"filters" => build_template_filter(template_id)})
  end

  @doc """
  Add a tag to the list of substitutions in the SendGrid template.

  The tag must be a `String.t` due to SendGrid using special characters to wrap
  tags in the template.

  ## Example

      email
      |> substitute("%name%", "Jon Snow")
  """
  def substitute(%Email{private: %{"x-smtpapi" => _}} = email, tag, value) when is_binary(tag) do
    substitutions = Map.get(email.private["x-smtpapi"], "sub", %{})
      |> Map.merge(%{tag => [value]})

    fields = email.private["x-smtpapi"]
      |> Map.merge(%{"sub" => substitutions})

    email |> Email.put_private("x-smtpapi", fields)
  end

  def substitute(email, tag, value) when is_binary(tag) do
    email |> Email.put_private("x-smtpapi", %{"sub" => %{tag => [value]}})
  end

  defp build_template_filter(template_id) do
    %{
      "templates" => %{
        "settings" => %{
          "enabled" => 1,
          "template_id" => template_id
        }
      }
    }
  end
end

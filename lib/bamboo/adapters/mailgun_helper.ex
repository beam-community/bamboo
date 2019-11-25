defmodule Bamboo.MailgunHelper do
  @moduledoc """
  Functions for using features specific to Mailgun
  (e.g. tagging, templates).
  """

  alias Bamboo.Email

  @doc """
  Add a tag to outgoing email to help categorize traffic based on some
  criteria, perhaps separate signup emails from password recovery emails
  or from user comments.

  More details can be found in the
  [Mailgun documentation](https://documentation.mailgun.com/en/latest/user_manual.html#tagging)

  ## Example

      email
      |> MailgunHelper.tag("welcome-email")
  """
  def tag(email, tag) do
    Email.put_private(email, :"o:tag", tag)
  end

  @doc """
  Send an email using a template stored in Mailgun, rather than supplying
  a `Bamboo.Email.text_body/2` or a `Bamboo.Email.html_body/2`.

  More details about templates can be found in the
  [Templates section of the Mailgun documentation](https://documentation.mailgun.com/en/latest/user_manual.html#templates).
  """
  def template(email, template_name) do
    Email.put_private(email, :template, template_name)
  end

  @doc """
  Use it to send a message to specific version of a template.

  More details can be found in the
  [Mailgun documentation](https://documentation.mailgun.com/en/latest/api-sending.html#sending)

  ## Example

      email
      |> MailgunHelper.template("my-template")
      |> MailgunHelper.template_version("v2")
  """
  def template_version(email, version), do: Email.put_private(email, :"t:version", version)

  @doc """
  Use it if you want to have rendered template in the text part of the
  message in case of template sending.

  More details can be found in the
  [Mailgun documentation](https://documentation.mailgun.com/en/latest/api-sending.html#sending)

  ## Example

      email
      |> MailgunHelper.template_text(true)
  """
  def template_text(email, true), do: Email.put_private(email, :"t:text", true)
  def template_text(email, _), do: Email.put_private(email, :"t:text", false)

  @doc """
  When sending an email with `Bamboo.MailgunHelper.template/2` you can
  replace a handlebars variables using this function.

  More details about templates can be found in the
  [Templates section of the Mailgun documentation](https://documentation.mailgun.com/en/latest/user_manual.html#templates).

  ## Example

      email
      |> MailgunHelper.template("password-reset-email")
      |> MailgunHelper.substitute_variables("password_reset_link", "https://example.com/123")

  """
  def substitute_variables(email, key, value) do
    substitute_variables(email, %{key => value})
  end

  @doc """
  This behaves like `Bamboo.MailgunHelper.substitute_variables/3`, but
  accepts a `Map` rather than a key, value pair.

  ## Example

      email
      |> MailgunHelper.template("password-reset-email")
      |> MailgunHelper.substitute_variables(%{ "greeting" => "Hello!", "password_reset_link" => "https://example.com/123" })

  """
  def substitute_variables(email, variables = %{}) do
    custom_vars = Map.get(email.private, :mailgun_custom_vars, %{})
    Email.put_private(email, :mailgun_custom_vars, Map.merge(custom_vars, variables))
  end
end

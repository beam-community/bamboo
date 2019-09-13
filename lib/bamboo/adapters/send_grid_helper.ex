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

  @field_name :send_grid_template
  @categories :categories
  @asm_group_id :asm_group_id
  @bypass_list_management :bypass_list_management
  @google_analytics_enabled :google_analytics_enabled
  @google_analytics_utm_params :google_analytics_utm_params
  @allowed_google_analytics_utm_params ~w(utm_source utm_medium utm_campaign utm_term utm_content)a

  @doc """
  Specify the template for SendGrid to use for the context of the substitution
  tags.

  ## Example

      email
      |> with_template("80509523-83de-42b6-a2bf-54b7513bd2aa")
  """
  def with_template(email, template_id) do
    template = Map.get(email.private, @field_name, %{})

    email
    |> Email.put_private(@field_name, set_template(template, template_id))
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

  @doc """
  An array of category names for this email. A maximum of 10 categories can be assigned to an email.
  Duplicate categories will be ignored and only unique entries will be sent.

  ## Example

      email
      |> with_categories("campaign-12345")
  """
  def with_categories(email, categories) when is_list(categories) do
    categories =
      (Map.get(email.private, @categories, []) ++ categories)
      |> MapSet.new()
      |> MapSet.to_list()

    email
    |> Email.put_private(@categories, Enum.slice(categories, 0, 10))
  end

  def with_categories(_email, _categories) do
    raise "expected a list of category strings"
  end

  @doc """
  Add a property to the list of dynamic template data in the SendGrid template.
  This will be added to the request as:

  ...
   "personalizations":[
      {
         "to":[
            {
               "email":"example@sendgrid.net"
            }
         ],
         "dynamic_template_data":{
            "total":"$ 239.85",
         }
      }
   ],
  ...


  The tag can be of any type since SendGrid allows you to use Handlebars in its templates

  ## Example

      email
      |> add_data("name", "Jon Snow")
  """
  def add_dynamic_field(email, field, value) when is_atom(field),
    do: add_dynamic_field(email, Atom.to_string(field), value)

  def add_dynamic_field(email, field, value) when is_binary(field) do
    template = Map.get(email.private, @field_name, %{})

    email
    |> Email.put_private(@field_name, add_dynamic_field_to_template(template, field, value))
  end

  def add_dynamic_field(_email, field, _value),
    do: raise("expected the name parameter to be of type binary or atom, got #{field}")

  @doc """
  An integer id for an ASM (Advanced Suppression Manager) group that this email should belong to.
  This can be used to let recipients unsubscribe from only a certain type of communication.

  ## Example

      email
      |> with_asm_group_id(1234)
  """
  def with_asm_group_id(email, asm_group_id) when is_integer(asm_group_id) do
    email
    |> Email.put_private(@asm_group_id, asm_group_id)
  end

  def with_asm_group_id(_email, asm_group_id) do
    raise "expected the asm_group_id parameter to be an integer, got #{asm_group_id}"
  end

  @doc """
  A boolean setting to instruct SendGrid to bypass list management for this
  email. If enabled, SendGrid will ignore any email supression (such as
  unsubscriptions, bounces, spam filters) for this email. This is useful for
  emails that all users must receive, such as Terms of Service updates, or
  password resets.

  ## Example

      email
      |> with_bypass_list_management(true)
  """
  def with_bypass_list_management(email, enabled) when is_boolean(enabled) do
    email
    |> Email.put_private(@bypass_list_management, enabled)
  end

  def with_bypass_list_management(_email, enabled) do
    raise "expected bypass_list_management parameter to be a boolean, got #{enabled}"
  end

  @doc """
  Instruct SendGrid to enable or disable Google Analytics tracking, and
  optionally set the UTM parameters for it. This is useful if you need to
  control UTM tracking parameters on an individual email basis.

  ## Example

      email
      |> with_google_analytics(true, %{utm_source: "email", utm_campaign: "campaign"})

      email
      |> with_google_analytics(false)
  """
  def with_google_analytics(email, enabled, utm_params \\ %{})

  def with_google_analytics(email, enabled, utm_params)
      when is_boolean(enabled) do
    utm_params =
      utm_params
      |> Map.take(@allowed_google_analytics_utm_params)

    email
    |> Email.put_private(@google_analytics_enabled, enabled)
    |> Email.put_private(@google_analytics_utm_params, utm_params)
  end

  def with_google_analytics(_email, _enabled, _utm_params) do
    raise "expected with_google_analytics enabled parameter to be a boolean"
  end

  defp set_template(template, template_id) do
    template
    |> Map.merge(%{template_id: template_id})
  end

  defp add_substitution(template, tag, value) do
    template
    |> Map.update(:substitutions, %{tag => value}, fn substitutions ->
      Map.merge(substitutions, %{tag => value})
    end)
  end

  defp add_dynamic_field_to_template(template, field, value) do
    template
    |> Map.update(:dynamic_template_data, %{field => value}, fn dynamic_data ->
      Map.merge(dynamic_data, %{field => value})
    end)
  end
end

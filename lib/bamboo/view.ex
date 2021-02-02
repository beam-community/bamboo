defmodule Bamboo.View do
  @moduledoc """
  Compiles and renders templates defined in a given path.

  Functions defined in the view are available to use in its templates.

  ## Example

      defmodule MyApp.EmailView do
        use Bamboo.View, path: "lib/my_app/email/templates"

        def app_title do
          "My Super App"
        end
      end

      # lib/my_app/email_templates/welcome.html
      <h1>Welcome to <%= app_title() %></h1>
  """

  defmodule UndefinedTemplateError do
    @moduledoc """
    Exception raised when a template cannot be found.
    """
    defexception [:module, :template, :available]

    def message(exception) do
      ~s"""
      Could not render #{inspect(exception.template)} for #{inspect(exception.module)}

      #{available_templates(exception.available)}
      """
    end

    defp available_templates([]), do: "No templates were compiled for this module."

    defp available_templates(available) do
      "The following templates were compiled:\n\n" <>
        Enum.map_join(available, "\n", &"* #{&1}") <>
        "\n"
    end
  end

  defmacro __using__(path: path) do
    quote do
      @templates_path unquote(path)
      @before_compile unquote(__MODULE__)
    end
  end

  defmacro __using__(opts) do
    raise ArgumentError, """
    expected Bamboo.View to have a path set, instead got: #{inspect(opts)}.

    Please set a path where this view's template are defined e.g. use Bamboo.View, path: "lib/my_app/email/templates/account"
    """
  end

  defmacro __before_compile__(env) do
    templates_path = Module.get_attribute(env.module, :templates_path)

    results =
      templates_path
      |> templates_to_compile()
      |> Enum.map(&template_and_name/1)
      |> Enum.map(fn {template, name} ->
        {name, compile(template, name)}
      end)

    template_names = Enum.map(results, &elem(&1, 0))
    render_functions = Enum.map(results, &elem(&1, 1))

    quote do
      unquote(render_functions)

      def render_template(template, _assigns) do
        raise UndefinedTemplateError,
          module: __MODULE__,
          template: template,
          available: unquote(template_names)
      end
    end
  end

  @doc false
  def render(email, template) when is_atom(template) do
    render_html_and_text_emails(email, template)
  end

  def render(email, template) do
    render_text_or_html_email(email, template)
  end

  defp render_html_and_text_emails(email, template) do
    view_template = Atom.to_string(template)

    email
    |> Map.put(:html_body, render_html(email, view_template <> ".html"))
    |> Map.put(:text_body, render_text(email, view_template <> ".text"))
  end

  defp render_text_or_html_email(email, template) do
    cond do
      String.ends_with?(template, ".html") ->
        Map.put(email, :html_body, render_html(email, template))

      String.ends_with?(template, ".text") ->
        Map.put(email, :text_body, render_text(email, template))

      true ->
        raise ArgumentError, """
        Template name must end in either ".html" or ".text". Template name was #{
          inspect(template)
        }

        If you would like to render both and html and text template,
        use an atom without an extension instead.
        """
    end
  end

  defp render_html(email, template) do
    layout = email.private.html_layout
    render_within_layout(layout, email, template)
  end

  defp render_text(email, template) do
    layout = email.private.text_layout
    render_within_layout(layout, email, template)
  end

  defp render_within_layout(_layout = false, email, template) do
    module = email.private.view_module
    module.render_template(template, email.assigns)
  end

  defp render_within_layout({layout_view, layout_template}, email, template) do
    module = email.private.view_module
    contents = module.render_template(template, email.assigns)

    assigns = Map.put(email.assigns, :inner_content, contents)

    layout_view.render_template(layout_template, assigns)
  end

  defp templates_to_compile(directory) do
    Path.wildcard(directory <> "/*.eex")
  end

  defp template_and_name(template) do
    name =
      template
      |> Path.basename()
      |> Path.rootname(".eex")

    {template, name}
  end

  defp compile(template, name) do
    quoted_contents = EEx.compile_file(template, line: 1, engine: EEx.SmartEngine)
    function_name = String.to_atom(name)

    quote do
      @file unquote(name)
      @external_resource unquote(template)

      defp unquote(function_name)(var!(assigns)) do
        _ = var!(assigns)
        unquote(quoted_contents)
      end

      def render_template(unquote(name), assigns) do
        unquote(function_name)(assigns)
      end
    end
  end
end

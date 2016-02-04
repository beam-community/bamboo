defmodule Bamboo.Phoenix do
  defmacro __using__(view: view_module) do
    verify_phoenix_dep
    quote do
      import Bamboo.Email
      @email_view_module unquote(view_module)

      def render(email, template, assigns \\ []) do
        Bamboo.Phoenix.render_email(@email_view_module, email, template, assigns)
      end
    end
  end

  defp verify_phoenix_dep do
    unless Code.ensure_loaded?(Phoenix) do
      raise "You tried to use Bamboo.Phoenix, but Phoenix module is not loaded. " <>
      "Please add phoenix to your dependencies."
    end
  end

  def render_email(view, email, template, assigns) when is_atom(template) do
    template = Atom.to_string(template)

    email
    |> Map.put(:html_body, render_email(view, template <> ".html", assigns))
    |> Map.put(:text_body, render_email(view, template <> ".text", assigns))
  end

  def render_email(view, email, template, assigns) when is_binary(template) do
    cond do
      String.ends_with?(template, ".html") ->
        email |> Map.put(:html_body, render_email(view, template, assigns))
      String.ends_with?(template, ".text") ->
        email |> Map.put(:text_body, render_email(view, template, assigns))
      true -> raise ArgumentError, """
        Template name must end in either ".html" or ".text". Template name was #{inspect template}

        If you would like to render both and html and text template,
        use an atom without an extension instead.
        """
    end
  end

  defp render_email(view, template, assigns) do
    Phoenix.View.render_to_string(view, template, assigns)
  end
end

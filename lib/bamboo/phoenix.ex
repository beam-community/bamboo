defmodule Bamboo.Phoenix do
  import Bamboo.Email, only: [put_private: 3]

  defmacro __using__(view: view_module) do
    verify_phoenix_dep
    quote do
      import Bamboo.Email
      import Bamboo.Phoenix
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

  def put_html_layout(email, layout) do
    email |> put_private(:html_layout, layout)
  end

  def put_text_layout(email, layout) do
    email |> put_private(:text_layout, layout)
  end

  def assign(%{assigns: assigns} = email, key, value) do
    %{email | assigns: Map.put(assigns, key, value)}
  end

  def render_email(view, email, template, assigns) do
    email
    |> put_default_layouts
    |> merge_assigns(assigns)
    |> put_view(view)
    |> put_template(template)
    |> render
  end

  defp put_default_layouts(%{private: private} = email) do
    private = private
      |> Map.put_new(:html_layout, false)
      |> Map.put_new(:text_layout, false)
    %{email | private: private}
  end

  defp merge_assigns(%{assigns: email_assigns} = email, assigns) do
    assigns = email_assigns |> Map.merge(Enum.into(assigns, %{}))
    email |> Map.put(:assigns, assigns)
  end

  defp put_view(email, view_module) do
    email |> put_private(:view_module, view_module)
  end

  defp put_template(email, view_template) do
    email |> put_private(:view_template, view_template)
  end

  defp render(%{private: %{view_template: template}} = email) when is_atom(template) do
    render_html_and_text_emails(email)
  end

  defp render(email) do
    render_text_or_html_email(email)
  end

  defp render_html_and_text_emails(email) do
    view_template = Atom.to_string(email.private.view_template)

    email
    |> Map.put(:html_body, render_html(email, view_template <> ".html"))
    |> Map.put(:text_body, render_text(email, view_template <> ".text"))
  end

  defp render_text_or_html_email(email) do
    template = email.private.view_template

    cond do
      String.ends_with?(template, ".html") ->
        email |> Map.put(:html_body, render_html(email, template))
      String.ends_with?(template, ".text") ->
        email |> Map.put(:text_body, render_text(email, template))
      true -> raise ArgumentError, """
        Template name must end in either ".html" or ".text". Template name was #{inspect template}

        If you would like to render both and html and text template,
        use an atom without an extension instead.
        """
    end
  end

  defp render_html(email, template) do
    # Phoenix uses the assigns.layout to determine what layout to use
    assigns = Map.put(email.assigns, :layout, email.private.html_layout)

    Phoenix.View.render_to_string(
      email.private.view_module,
      template,
      assigns
    )
  end

  defp render_text(email, template) do
    assigns = Map.put(email.assigns, :layout, email.private.text_layout)

    Phoenix.View.render_to_string(
      email.private.view_module,
      template,
      assigns
    )
  end
end

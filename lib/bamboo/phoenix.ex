defmodule Bamboo.Phoenix do
  @moduledoc """
  Render templates and layouts with Phoenix.

  This module makes it very easy to render layouts and views using Phoenix.
  Pass an atom (e.g. `:welcome_email`) as the template name to render HTML and
  plain text emails. Use a string if you only want to render one type, e.g.
  `"welcome_email.text"` or `"welcome_email.html"`.

  ## Examples

      defmodule Email do
        use Bamboo.Phoenix, view: MyApp.EmailView

        def text_and_html_email_with_layout do
          new_email()
          # You could set just a text layout or just an html layout
          |> put_text_layout({MyApp.LayoutView, "email.text"})
          |> put_html_layout({MyApp.LayoutView, "email.html"})
          # Or you can set a layout for both html and text at the same time
          |> put_layout({MyApp.LayoutView, :email})
          # Pass an atom to render html AND plain text templates
          |> render(:text_and_html_email)
        end

        def text_and_html_email_without_layouts do
          new_email()
          |> render(:text_and_html_email)
        end

        def email_with_assigns(user) do
          new_email()
          # @user will be available in the template
          |> render(:email_with_assigns, user: user)
        end

        def email_with_already_assigned_user(user) do
          new_email()
          # @user will be available in the template
          |> assign(:user, user)
          |> render(:email_with_assigns)
        end

        def html_email do
          new_email
          |> render("html_email.html")
        end

        def text_email do
          new_email
          |> render("text_email.text")
        end
      end

  ## HTML Layout Example

      # web/email.ex
      defmodule Myapp.Email do
        use Bamboo.Phoenix, view: Myapp.EmailView

        def sign_in_email(person) do
          base_email
          |> to(person)
          |> subject("Your Sign In Link")
          |> assign(:person, person)
          |> render(:sign_in)
        end

        defp base_email do
          new_email
          |> from("Rob Ot<robot@changelog.com>")
          |> put_header("Reply-To", "editors@changelog.com")
          # This will use the "email.html.eex" file as a layout when rendering html emails.
          # Plain text emails will not use a layout unless you use `put_text_layout`
          |> put_html_layout({Myapp.LayoutView, "email.html"})
        end
      end

      # web/views/email_view.ex
      defmodule Myapp.EmailView do
        use Myapp.Web, :view
      end

      # web/templates/layout/email.html.eex
      <html>
        <head>
          <link rel="stylesheet" href="<%= static_url(Myapp.Endpoint, "/css/email.css") %>">
        </head>
        <body>
          <%= render @view_module, @view_template, assigns %>
        </body>
      </html>

      # web/templates/email/sign_in.html.eex
      <p><%= link "Sign In", to: sign_in_url(Myapp.Endpoint, :create, @person) %></p>

      # web/templates/email/sign_in.text.eex
      # This will not be rendered within a layout because `put_text_layout` was not used.
      Sign In: <%= sign_in_url(Myapp.Endpoint, :create, @person) %>
  """

  import Bamboo.Email, only: [put_private: 3]

  defmacro __using__(view: view_module) do
    verify_phoenix_dep()
    quote do
      import Bamboo.Email
      import Bamboo.Phoenix, except: [render: 3]
      @email_view_module unquote(view_module)

      @doc """
      Render an Phoenix template and set the body on the email

      Pass an atom as the template name (:welcome_email) to render HTML *and* plain
      text emails. Use a string if you only want to render one type, e.g.
      "welcome_email.text" or "welcome_email.html". Scroll to the top for more examples.
      """
      def render(email, template, assigns \\ []) do
        Bamboo.Phoenix.render_email(@email_view_module, email, template, assigns)
      end
    end
  end
  defmacro __using__(opts) do
    raise ArgumentError, """
    expected Bamboo.Phoenix to have a view set, instead got: #{inspect opts}.

    Please set a view e.g. use Bamboo.Phoenix, view: MyApp.MyView
    """
  end

  defp verify_phoenix_dep do
    unless Code.ensure_loaded?(Phoenix) do
      raise "You tried to use Bamboo.Phoenix, but Phoenix module is not loaded. " <>
      "Please add phoenix to your dependencies."
    end
  end

  @doc """
  Render a Phoenix template and set the body on the email

  Pass an atom as the template name to render HTML *and* plain text emails,
  e.g. `:welcome_email`. Use a string if you only want to render one type, e.g.
  `"welcome_email.text"` or `"welcome_email.html"`. Scroll to the top for more examples.
  """
  def render(_email, _template_name, _assigns) do
    raise "function implemented for documentation only, please call: use Bamboo.Phoenix"
  end

  @doc """
  Sets the layout when rendering HTML templates

  ## Example

      def html_email_layout do
        new_email
        # Will use MyApp.LayoutView with email.html template when rendering html emails
        |> put_html_layout({MyApp.LayoutView, "email.html"})
      end
  """
  def put_html_layout(email, layout) do
    email |> put_private(:html_layout, layout)
  end

  @doc """
  Sets the layout when rendering plain text templates

  ## Example

      def text_email_layout do
        new_email
        # Will use MyApp.LayoutView with email.text template when rendering text emails
        |> put_text_layout({MyApp.LayoutView, "email.text"})
      end
  """
  def put_text_layout(email, layout) do
    email |> put_private(:text_layout, layout)
  end

  @doc """
  Sets the layout for rendering plain text and HTML templates

  ## Example

      def text_and_html_email_layout do
        new_email
        # Will use MyApp.LayoutView with the email.html template for html emails
        # and MyApp.LayoutView with the email.text template for text emails
        |> put_layout({MyApp.LayoutView, :email})
      end
  """
  def put_layout(email, {layout, template}) do
    email
    |> put_text_layout({layout, to_string(template) <> ".text"})
    |> put_html_layout({layout, to_string(template) <> ".html"})
  end

  @doc """
  Sets an assign for the email. These will be availabe when rendering the email
  """
  def assign(%{assigns: assigns} = email, key, value) do
    %{email | assigns: Map.put(assigns, key, value)}
  end

  @doc false
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

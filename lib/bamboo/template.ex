defmodule Bamboo.Template do
  @moduledoc """
  Render emails with layouts, view modules, and templates.

  This module allows rendering emails with layouts and views. Pass an
  atom (e.g. `:welcome_email`) as the template name to render both HTML and
  plain text emails. Use a string if you only want to render one type, e.g.
  `"welcome_email.text"` or `"welcome_email.html"`.

  ## Examples

  _Set the text and HTML layout for an email._

      defmodule MyApp.Email do
        use Bamboo.Template, view: MyApp.Email.AccountView

        def welcome_email do
          new_email()
          |> put_text_layout({MyApp.Email.LayoutView, "email.text"})
          |> put_html_layout({MyApp.Email.LayoutView, "email.html"})
          |> render(:welcome) # Pass atom to render html AND plain text templates
        end
      end

  _You can optionally pass the html and text layouts when calling `use Bamboo.Template`_

      defmodule MyApp.Email do
        use Bamboo.Template,
          view: MyApp.Email.AccountView
          text_layout: {MyApp.Email.LayoutView, "email.text"},
          html_layout: {MyApp.Email.LayoutView, "email.html"}

        def welcome_email do
          new_email()
          |> render(:welcome) # Pass atom to render html AND plain text templates
        end
      end

  _Set both the text and HTML layout at the same time for an email._

      defmodule MyApp.Email do
        use Bamboo.Template, view: MyApp.Email.AccountView

        def welcome_email do
          new_email()
          |> put_layout({MyApp.Email.LayoutView, :email})
          |> render(:welcome)
        end
      end

  _Render both text and html emails without layouts._

      defmodule MyApp.Email do
        use Bamboo.Template, view: MyApp.Email.AccountView

        def welcome_email do
          new_email()
          |> render(:welcome)
        end
      end

  _Make assigns available to a template._

      defmodule MyApp.Email do
        use Bamboo.Template, view: MyApp.Email.AccountView

        def welcome_email(user) do
          new_email()
          |> assign(:user, user)
          |> render(:welcome)
        end
      end

  _Make assigns available to a template during render call._

      defmodule MyApp.Email do
        use Bamboo.Template, view: MyApp.Email.AccountView

        def welcome_email(user) do
          new_email()
          |> render(:welcome, user: user)
        end
      end

  _Render an email by passing the template string to render._

      defmodule MyApp.Email do
        use Bamboo.Template, view: MyApp.Email.AccountView

        def html_email do
          new_email()
          |> render("html_email.html")
        end

        def text_email do
          new_email
          |> render("text_email.text")
        end
      end

  ## HTML Layout Example

      # lib/my_app/email.ex
      defmodule MyApp.Email do
        use Bamboo.Template, view: MyApp.Email.AccountView

        def welcome_email(person) do
          base_email()
          |> to(person)
          |> subject("Welcome to MyApp")
          |> assign(:person, person)
          |> render(:welcome_email)
        end

        defp base_email do
          new_email()
          |> from("Rob Ot<robot@changelog.com>")
          |> put_header("Reply-To", "editors@changelog.com")
          # This will use the "email.html.eex" file as a layout when rendering html emails.
          # Plain text emails will not use a layout unless you use `put_text_layout`
          |> put_html_layout({MyApp.Email.LayoutView, "email.html"})
        end
      end

      # lib/my_app/email/views/layout_view.ex
      defmodule MyApp.Email.LayoutView do
        use Bamboo.View, path: "lib/my_app/email/templates/layout"
      end

      # lib/my_app/email/templates/layout/email.html.eex
      <html>
        <body>
          <%= @inner_content %>
        </body>
      </html>

      # lib/my_app/email/views/account_view.ex
      defmodule MyApp.Email.AccountView do
        use Bamboo.View, path: "lib/my_app/email/templates/account"
      end

      # lib/my_app/email/templates/account/welcome_email.html.eex
      # This will be rendered within a layout because `put_html_layout` was used.
      <p>Welcome <%= @person.name %></p>

      # lib/my_app/email/templates/account/welcome_email.text.eex
      # This will not be rendered within a layout because `put_text_layout` was not used.
      Welcome <%= @person.name %>
  """

  import Bamboo.Email, only: [put_private: 3]

  defmacro __using__(opts) do
    view = Keyword.get(opts, :view, :unset)
    html_layout = Keyword.get(opts, :html_layout, false)
    text_layout = Keyword.get(opts, :text_layout, false)

    quote do
      import Bamboo.Email
      import Bamboo.Template, except: [render: 3]

      def render(email, template, assigns \\ []) do
        render_email(
          unquote(view),
          unquote(html_layout),
          unquote(text_layout),
          email,
          template,
          assigns
        )
      end
    end
  end

  @doc """
  Render a template and set the body on the email.

  Pass an atom as the template name to render HTML *and* plain text emails,
  e.g. `:welcome_email`. Use a string if you only want to render one type, e.g.
  `"welcome_email.text"` or `"welcome_email.html"`.

  You can also optionally pass assigns.

  ## Example

      # renders both HTML and text emails
      new_email()
      |> render(:template_name)

      # renders HTML template
      new_email()
      |> render("template_name.html")

      # renders text template
      new_email()
      |> render("template_name.text")

      # renders with assigns
      new_email()
      |> render(:template_name, user: user)
  """
  def render(_email, _template_name, _assigns) do
    raise "function implemented for documentation only, please call: `use Bamboo.Template`"
  end

  @doc """
  Sets an assign for the email. These will be available when rendering the email

  ## Example

      new_email()
      # assigns user to be accessed as `@user` in template
      |> assign(:user, user)
      |> render(:template_name)
  """
  def assign(%{assigns: assigns} = email, key, value) do
    %{email | assigns: Map.put(assigns, key, value)}
  end

  @doc """
  Sets the layout when rendering HTML templates.

  ## Example

      def html_email_layout do
        new_email
        # Will use the email.html template of MyApp.LayoutView when rendering html emails
        |> put_html_layout({MyApp.LayoutView, "email.html"})
      end
  """
  def put_html_layout(email, layout) do
    email |> put_private(:html_layout, layout)
  end

  @doc """
  Sets the layout when rendering plain text templates.

  ## Example

      def text_email_layout do
        new_email
        # Will use the email.text template of MyApp.LayoutView when rendering text emails
        |> put_text_layout({MyApp.LayoutView, "email.text"})
      end
  """
  def put_text_layout(email, layout) do
    email |> put_private(:text_layout, layout)
  end

  @doc """
  Sets the layout for rendering plain text and HTML templates.

  ## Example

      def text_and_html_email_layout do
        new_email
        # Will use email.html and email.text templates of MyApp.LayoutView
        # when rendering HTML and text emails
        |> put_layout({MyAppWeb.LayoutView, :email})
      end
  """
  def put_layout(email, {layout, template}) do
    email
    |> put_text_layout({layout, to_string(template) <> ".text"})
    |> put_html_layout({layout, to_string(template) <> ".html"})
  end

  @doc """
  Overrides the view for rendering templates

  ## Example

      defmodule MyApp.Email do
        use Bamboo.Template, view: MyApp.EmailView

        def different_view_template do
          new_email
          # Will use welcome.html template of MyApp.AccountView
          |> put_view(MyApp.AccountView)
          |> render("welcome.html")
        end
      end
  """
  def put_view(email, view) do
    email |> put_private(:view_module, view)
  end

  @doc false
  def render_email(view, html_layout, text_layout, email, template, assigns) do
    email
    |> put_defaults(view, html_layout, text_layout)
    |> merge_assigns(assigns)
    |> render_template(template)
  end

  defp put_defaults(%{private: private} = email, view_module, html_layout, text_layout) do
    private =
      private
      |> Map.put_new(:html_layout, html_layout)
      |> Map.put_new(:text_layout, text_layout)
      |> Map.put_new(:view_module, view_module)

    %{email | private: private}
  end

  defp merge_assigns(%{assigns: email_assigns} = email, assigns) do
    assigns = Map.merge(email_assigns, Enum.into(assigns, %{}))
    Map.put(email, :assigns, assigns)
  end

  defp render_template(%{private: %{view_module: :unset}}, _template) do
    raise ArgumentError, """
    Expected Bamboo.Template to have a view set. Please set a view.

    You can set it at the template level:

      use Bamboo.Template, view: MyEmailView

    or call it in your pipeline:

      email
      |> put_view(MyEmailView)
      |> render("my_template.html")
    """
  end

  defp render_template(email, template) do
    Bamboo.View.render(email, template)
  end
end

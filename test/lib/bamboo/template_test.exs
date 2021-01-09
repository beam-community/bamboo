defmodule Bamboo.TemplateTest do
  use ExUnit.Case, async: true

  defmodule LayoutView do
    use Bamboo.View, path: "test/support/templates/layout"
  end

  defmodule AdminView do
    use Bamboo.View, path: "test/support/templates/admin_email"
  end

  defmodule EmailView do
    use Bamboo.View, path: "test/support/templates/email"

    def function_in_view do
      "Text in view"
    end
  end

  defmodule Email do
    use Bamboo.Template, view: EmailView

    def text_and_html_email_with_layout do
      new_email()
      |> put_layout({LayoutView, :app})
      |> render(:text_and_html_email)
    end

    def text_and_html_email do
      new_email()
      |> render(:text_and_html_email)
    end

    def email_with_assigns(user) do
      new_email()
      |> render(:email_with_assigns, user: user)
    end

    def email_with_already_assigned_user(user) do
      new_email()
      |> assign(:user, user)
      |> render(:email_with_assigns)
    end

    def html_email do
      new_email()
      |> render("html_email.html")
    end

    def text_email do
      new_email()
      |> render("text_email.text")
    end

    def text_and_html_calling_view_function_email do
      new_email()
      |> render(:text_and_html_calling_view_function_email)
    end

    def text_and_html_from_different_view do
      new_email()
      |> put_view(AdminView)
      |> render(:text_and_html_from_different_view)
    end

    def no_template do
      new_email()
      |> render(:non_existent)
    end

    def invalid_template do
      new_email()
      |> render("template.foobar")
    end
  end

  test "render/2 allows setting a custom layout" do
    email = Email.text_and_html_email_with_layout()

    assert email.html_body =~ "HTML layout"
    assert email.html_body =~ "HTML body"
    assert email.text_body =~ "TEXT layout"
    assert email.text_body =~ "TEXT body"
  end

  test "render/2 renders html and text emails" do
    email = Email.text_and_html_email()

    assert email.html_body =~ "HTML body"
    assert email.text_body =~ "TEXT body"
  end

  test "render/2 renders html and text emails with assigns" do
    name = "Paul"
    email = Email.email_with_assigns(%{name: name})
    assert email.html_body =~ "<strong>#{name}</strong>"
    assert email.text_body =~ name

    name = "Paul"
    email = Email.email_with_already_assigned_user(%{name: name})
    assert email.html_body =~ "<strong>#{name}</strong>"
    assert email.text_body =~ name
  end

  test "render/2 renders html body if template extension is .html" do
    email = Email.html_email()

    assert email.html_body =~ "HTML body"
    assert email.text_body == nil
  end

  test "render/2 renders text body if template extension is .text" do
    email = Email.text_email()

    assert email.html_body == nil
    assert email.text_body =~ "TEXT body"
  end

  test "render/2 can use functions in the view itself" do
    email = Email.text_and_html_calling_view_function_email()

    assert email.html_body =~ "Text in view"
    assert email.text_body =~ "Text in view"
  end

  test "render/2 allows overriding view with put_view" do
    email = Email.text_and_html_from_different_view()

    assert email.html_body =~ "HTML from different view"
    assert email.text_body =~ "TEXT from different view"
  end

  test "render/2 raises if template doesn't exist" do
    assert_raise Bamboo.View.UndefinedTemplateError, ~r/Could not render/, fn ->
      Email.no_template()
    end
  end

  test "render/2 raises if you pass an invalid template extension" do
    assert_raise ArgumentError, ~r/must end in either ".html" or ".text"/, fn ->
      Email.invalid_template()
    end
  end

  test "render raises if called directly" do
    assert_raise RuntimeError, ~r/documentation only/, fn ->
      Bamboo.Template.render(:foo, :foo, :foo)
    end
  end
end

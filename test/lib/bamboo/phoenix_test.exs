defmodule Bamboo.PhoenixTest do
  use ExUnit.Case

  defmodule Emails do
    use Bamboo.Phoenix, view: Bamboo.EmailView

    def text_and_html_email do
      new_email()
      |> render(:text_and_html_email)
    end

    def email_with_assigns(user) do
      new_email()
      |> render(:email_with_assigns, user: user)
    end

    def html_email do
      new_email
      |> render("html_email.html")
    end

    def text_email do
      new_email
      |> render("text_email.text")
    end

    def no_template do
      new_email
      |> render(:non_existent)
    end

    def invalid_template do
      new_email
      |> render("template.foobar")
    end
  end

  test "render/2 renders html and text emails" do
    email = Emails.text_and_html_email

    assert email.html_body =~ "HTML body"
    assert email.text_body =~ "TEXT body"
  end

  test "render/2 renders html and text emails with assigns" do
    name = "Paul"
    email = Emails.email_with_assigns(%{name: name})

    assert email.html_body =~ "<strong>#{name}</strong>"
    assert email.text_body =~ name
  end

  test "render/2 renders html body if template extension is .html" do
    email = Emails.html_email

    assert email.html_body =~ "HTML body"
    assert email.text_body == nil
  end

  test "render/2 renders text body if template extension is .text" do
    email = Emails.text_email

    assert email.html_body == nil
    assert email.text_body =~ "TEXT body"
  end

  test "render/2 raises if template doesn't exist" do
    assert_raise Phoenix.Template.UndefinedError, fn ->
      Emails.no_template
    end
  end

  test "render/2 raises if you pass an invalid template extension" do
    assert_raise ArgumentError, ~r/must end in either ".html" or ".text"/, fn ->
      Emails.invalid_template
    end
  end
end

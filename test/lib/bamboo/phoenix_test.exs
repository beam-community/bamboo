defmodule Bamboo.PhoenixTest do
  use ExUnit.Case

  defmodule Emails do
    use Bamboo.Phoenix

    def text_and_html_email do
      new_email()
      |> render("text_and_html_email")
    end

    def email_with_assigns(user) do
      new_email()
      |> render("email_with_assigns", user: user)
    end

    def html_email do
      new_email
      |> render("html_email")
    end

    def text_email do
      new_email
      |> render("text_email")
    end

    def no_template do
      new_email
      |> render("no_template")
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

  test "render/2 renders just html if there is only an html template" do
    email = Emails.html_email

    assert email.html_body =~ "HTML body"
    assert email.text_body == ""
  end

  test "render/2 renders just text if there is only a text template" do
    email = Emails.text_email

    assert email.html_body == ""
    assert email.text_body =~ "TEXT body"
  end

  test "render/2 raises if both templates are blank" do
    assert_raise ArgumentError, fn ->
      Emails.no_template
    end
  end
end

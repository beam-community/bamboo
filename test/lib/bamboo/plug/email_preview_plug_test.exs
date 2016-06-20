defmodule Bamboo.EmailPreviewTest do
  use ExUnit.Case
  use Plug.Test
  import Bamboo.Factory
  alias Bamboo.SentEmail

  defmodule AppRouter do
    use Plug.Router

    plug :match
    plug :dispatch

    forward "/sent_emails/foo", to: Bamboo.EmailPreviewPlug
    forward "/", to: Bamboo.EmailPreviewPlug
  end

  setup do
    SentEmail.reset
    :ok
  end

  test "shows list of all sent emails, and previews the newest email" do
    emails = normalize_and_push_pair(:email)
    conn = conn(:get, "/sent_emails/foo")

    conn = AppRouter.call(conn, nil)

    assert conn.status == 200
    assert selected_sidebar_email_text(conn) =~ newest_email.subject
    assert showing_in_preview_pane?(conn, newest_email)
    refute showing_in_preview_pane?(conn, oldest_email)
    for email <- emails do
      assert Floki.raw_html(sidebar(conn)) =~ ~s(href="/sent_emails/foo/#{SentEmail.get_id(email)}")
      assert Floki.text(sidebar(conn)) =~ email.subject
      assert Floki.text(sidebar(conn)) =~ Bamboo.Email.get_address(email.from)
    end
  end

  test "normalizes and shows all recipients" do
    mixed_to = ["to@bar.com", {"John", "john@gmail.com"}]
    mixed_cc = ["cc@bar.com", {"Paul", "paul@gmail.com"}]
    mixed_bcc = ["bcc@bar.com", {"Bob", "Bob@gmail.com"}]
    email = normalize_and_push(:email, from: {"Me", "me@foo.com"}, to: mixed_to, cc: mixed_cc, bcc: mixed_bcc)
    conn = conn(:get, "/sent_emails/foo")

    conn = AppRouter.call(conn, nil)

    assert conn.status == 200
    assert conn.resp_body =~ Bamboo.Email.get_address(email.from)
    for email_address <- Bamboo.Email.all_recipients(email) do
      assert conn.resp_body =~ Bamboo.Email.get_address(email_address)
    end
  end

  defp selected_sidebar_email_text(conn) do
    sidebar(conn) |> Floki.find("a.selected-email") |> Floki.text
  end

  test "doesn't have double slash if forwarded at root" do
    email = normalize_and_push(:email)
    conn = conn(:get, "/")

    conn = AppRouter.call(conn, nil)

    assert conn.status == 200
    assert Floki.raw_html(sidebar(conn)) =~ ~s(href="/#{SentEmail.get_id(email)}")
    assert Floki.text(sidebar(conn)) =~ email.subject
  end

  test "shows notice if no emails exist" do
    conn = conn(:get, "/sent_emails/foo")

    conn = AppRouter.call(conn, nil)

    assert conn.status == 200
    assert conn.resp_body =~ "No emails have been sent"
  end

  test "shows an email by id" do
    normalize_and_push_pair(:email)
    selected_email_id = SentEmail.all |> Enum.at(0) |> SentEmail.get_id
    unselected_email_id = SentEmail.all |> Enum.at(1) |> SentEmail.get_id
    conn = conn(:get, "/sent_emails/foo/#{selected_email_id}")

    conn = AppRouter.call(conn, nil)

    assert conn.status == 200
    assert showing_in_preview_pane?(conn, SentEmail.get(selected_email_id))
    refute showing_in_preview_pane?(conn, SentEmail.get(unselected_email_id))
  end

  test "shows an email's html by id" do
    normalize_and_push_pair(:html_email)
    selected_email_id = SentEmail.all |> Enum.at(0) |> SentEmail.get_id
    conn = conn(:get, "/sent_emails/foo/#{selected_email_id}/html")

    conn = AppRouter.call(conn, nil)

    assert conn.status == 200
    assert conn.resp_body =~ SentEmail.get(selected_email_id).html_body
  end

  test "shows error if email could not be found" do
    conn = conn(:get, "/sent_emails/foo/non_existent_id")

    conn = AppRouter.call(conn, nil)

    assert conn.status == 404
    assert conn.resp_body =~ "Email not found"
  end

  defp newest_email do
    SentEmail.all |> List.first
  end

  defp oldest_email do
    SentEmail.all |> List.last
  end

  defp showing_in_preview_pane?(conn, email) do
    Floki.text(preview_pane(conn)) =~ email.subject
  end

  defp preview_pane(conn) do
    conn.resp_body |> Floki.find(".email-preview-pane")
  end

  defp sidebar(conn) do
    conn.resp_body |> Floki.find(".email-sidebar")
  end
end

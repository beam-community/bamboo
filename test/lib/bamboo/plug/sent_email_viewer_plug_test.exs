defmodule Bamboo.SentEmailViewerPlugTest do
  use ExUnit.Case
  use Plug.Test
  import Bamboo.Factory
  alias Bamboo.SentEmail

  defmodule AppRouter do
    use Plug.Router

    plug :match
    plug :dispatch

    forward "/sent_emails/foo", to: Bamboo.SentEmailViewerPlug
    forward "/", to: Bamboo.SentEmailViewerPlug
  end

  setup do
    SentEmail.reset
    :ok
  end

  test "shows list of all sent emails, and the body of the newest email" do
    emails = normalize_and_push_pair(:email)
    conn = conn(:get, "/sent_emails/foo")

    conn = AppRouter.call(conn, nil)

    assert conn.status == 200
    assert {"content-type", "text/html; charset=utf-8"} in conn.resp_headers
    assert selected_sidebar_email_text(conn) =~ newest_email().subject
    assert showing_in_detail_pane?(conn, newest_email())
    refute showing_in_detail_pane?(conn, oldest_email())
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
    assert {"content-type", "text/html; charset=utf-8"} in conn.resp_headers
    assert conn.resp_body =~ Bamboo.Email.get_address(email.from)
    for email_address <- Bamboo.Email.all_recipients(email) do
      assert conn.resp_body =~ Bamboo.Email.get_address(email_address)
    end
  end

  test "prints single header in detail pane" do
    email = normalize_and_push(:email, headers: %{"Reply-To" => "reply-to@example.com"})
    conn = conn(:get, "/sent_emails/foo")

    conn = AppRouter.call(conn, nil)

    assert conn.status == 200
    assert {"content-type", "text/html; charset=utf-8"} in conn.resp_headers
    assert conn.resp_body =~ Bamboo.Email.get_address(email.from)
    assert conn.resp_body =~ "Reply-To"
    assert conn.resp_body =~ "reply-to@example.com"
  end

  test "prints multiple headers in detail pane" do
    email = normalize_and_push(:email, headers: %{"Reply-To" => ["reply-to1@example.com", "reply-to2@example.com"], "Foobar" => "foobar-header"})
    conn = conn(:get, "/sent_emails/foo")

    conn = AppRouter.call(conn, nil)

    assert conn.status == 200
    assert {"content-type", "text/html; charset=utf-8"} in conn.resp_headers
    assert conn.resp_body =~ Bamboo.Email.get_address(email.from)
    assert conn.resp_body =~ "Reply-To"
    assert conn.resp_body =~ "reply-to1@example.com"
    assert conn.resp_body =~ "reply-to2@example.com"
    assert conn.resp_body =~ "Foobar"
    assert conn.resp_body =~ "foobar-header"
  end

  test "falls back to inspect when printing header value that is not a string or list" do
    normalize_and_push(:email, headers: %{"SomeHeader" => %{"Some" => "Header"}})
    conn = conn(:get, "/sent_emails/foo")

    conn = AppRouter.call(conn, nil)

    assert conn.status == 200
    assert {"content-type", "text/html; charset=utf-8"} in conn.resp_headers
    assert conn.resp_body =~ "SomeHeader"
    assert conn.resp_body =~ "%{\"Some\" => \"Header\"}"
  end

  defp selected_sidebar_email_text(conn) do
    sidebar(conn) |> Floki.find("a.selected-email") |> Floki.text
  end

  test "doesn't have double slash if forwarded at root" do
    email = normalize_and_push(:email)
    conn = conn(:get, "/")

    conn = AppRouter.call(conn, nil)

    assert conn.status == 200
    assert {"content-type", "text/html; charset=utf-8"} in conn.resp_headers
    assert Floki.raw_html(sidebar(conn)) =~ ~s(href="/#{SentEmail.get_id(email)}")
    assert Floki.text(sidebar(conn)) =~ email.subject
  end

  test "shows notice if no emails exist" do
    conn = conn(:get, "/sent_emails/foo")

    conn = AppRouter.call(conn, nil)

    assert conn.status == 200
    assert {"content-type", "text/html; charset=utf-8"} in conn.resp_headers
    assert conn.resp_body =~ "No emails sent"
  end

  test "shows an email by id" do
    normalize_and_push_pair(:email)
    selected_email_id = SentEmail.all |> Enum.at(0) |> SentEmail.get_id
    unselected_email_id = SentEmail.all |> Enum.at(1) |> SentEmail.get_id
    conn = conn(:get, "/sent_emails/foo/#{selected_email_id}")

    conn = AppRouter.call(conn, nil)

    assert conn.status == 200
    assert {"content-type", "text/html; charset=utf-8"} in conn.resp_headers
    assert showing_in_detail_pane?(conn, SentEmail.get(selected_email_id))
    refute showing_in_detail_pane?(conn, SentEmail.get(unselected_email_id))
  end

  test "shows an email's html by id" do
    normalize_and_push_pair(:html_email)
    selected_email_id = SentEmail.all |> Enum.at(0) |> SentEmail.get_id
    conn = conn(:get, "/sent_emails/foo/#{selected_email_id}/html")

    conn = AppRouter.call(conn, nil)

    assert conn.status == 200
    assert {"content-type", "text/html; charset=utf-8"} in conn.resp_headers
    assert conn.resp_body =~ SentEmail.get(selected_email_id).html_body
  end

  test "sends an empty body for html emails if html body is nil" do
    normalize_and_push_pair(:email, html_body: nil)
    selected_email_id = SentEmail.all |> Enum.at(0) |> SentEmail.get_id
    conn = conn(:get, "/sent_emails/foo/#{selected_email_id}/html")

    conn = AppRouter.call(conn, nil)

    assert conn.status == 200
    assert {"content-type", "text/html; charset=utf-8"} in conn.resp_headers
    assert conn.resp_body == ""
  end

  test "shows error if email could not be found" do
    conn = conn(:get, "/sent_emails/foo/non_existent_id")

    conn = AppRouter.call(conn, nil)

    assert conn.status == 404
    assert {"content-type", "text/html; charset=utf-8"} in conn.resp_headers
    assert conn.resp_body =~ "Email not found"
  end

  defp newest_email do
    SentEmail.all |> List.first
  end

  defp oldest_email do
    SentEmail.all |> List.last
  end

  defp showing_in_detail_pane?(conn, email) do
    Floki.text(detail_pane(conn)) =~ email.subject
  end

  defp detail_pane(conn) do
    conn.resp_body |> Floki.find(".email-detail-pane")
  end

  defp sidebar(conn) do
    conn.resp_body |> Floki.find(".email-sidebar")
  end
end

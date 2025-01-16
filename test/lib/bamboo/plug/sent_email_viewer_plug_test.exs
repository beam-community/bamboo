defmodule Bamboo.SentEmailViewerPlugTest do
  use ExUnit.Case
  use Plug.Test
  import Bamboo.Factory
  alias Bamboo.SentEmail

  defmodule AppRouter do
    use Plug.Router

    plug(:match)
    plug(:dispatch)

    forward("/sent_emails/foo", to: Bamboo.SentEmailViewerPlug)
    forward("/", to: Bamboo.SentEmailViewerPlug)
  end

  setup do
    SentEmail.reset()
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
      assert conn |> sidebar() |> Floki.raw_html() =~
               ~s(href="/sent_emails/foo/#{SentEmail.get_id(email)}")

      assert conn |> sidebar() |> Floki.text() =~ email.subject
      assert conn |> sidebar() |> Floki.text() =~ Bamboo.Email.get_address(email.from)
    end
  end

  test "normalizes and shows all recipients" do
    mixed_to = ["to@bar.com", {"John", "john@gmail.com"}]
    mixed_cc = ["cc@bar.com", {"Paul", "paul@gmail.com"}]
    mixed_bcc = ["bcc@bar.com", {"Bob", "Bob@gmail.com"}]

    email =
      normalize_and_push(
        :email,
        from: {"Me", "me@foo.com"},
        to: mixed_to,
        cc: mixed_cc,
        bcc: mixed_bcc
      )

    conn = conn(:get, "/sent_emails/foo")

    conn = AppRouter.call(conn, nil)

    assert conn.status == 200
    assert {"content-type", "text/html; charset=utf-8"} in conn.resp_headers
    assert conn.resp_body =~ Bamboo.Email.get_address(email.from)

    for email_address <- Bamboo.Email.all_recipients(email) do
      assert conn.resp_body =~ Bamboo.Email.get_address(email_address)
    end
  end

  test "shows all senders" do
    mixed_from = ["from@bar.com", {"John", "john@foo.com"}]

    email =
      normalize_and_push(
        :email,
        from: mixed_from,
        to: {"Me", "me@foo.com"}
      )

    conn = conn(:get, "/sent_emails/foo")

    conn = AppRouter.call(conn, nil)

    assert conn.status == 200
    assert {"content-type", "text/html; charset=utf-8"} in conn.resp_headers

    for email_address <- email.from do
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
    email =
      normalize_and_push(
        :email,
        headers: %{
          "Reply-To" => ["reply-to1@example.com", "reply-to2@example.com"],
          "Foobar" => "foobar-header"
        }
      )

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
    assert conn.resp_body =~ "%{&quot;Some&quot; =&gt; &quot;Header&quot;}"
  end

  defp selected_sidebar_email_text(conn) do
    conn |> sidebar() |> Floki.find("a.selected-email") |> Floki.text()
  end

  test "shows attachment icon in sidebar for email with attachments" do
    attachment = build(:attachment)
    normalize_and_push(:email, attachments: [attachment])
    conn = conn(:get, "/sent_emails/foo")

    conn = AppRouter.call(conn, nil)

    assert conn.status == 200
    assert conn |> sidebar() |> Floki.find(".selected-email .email-attachment-icon") != []
  end

  test "does not show attachment icon in sidebar for email without attachments" do
    normalize_and_push(:email)
    conn = conn(:get, "/sent_emails/foo")

    conn = AppRouter.call(conn, nil)

    assert conn.status == 200
    assert conn |> sidebar() |> Floki.find(".selected-email .email-attachment-icon") == []
  end

  test "does not show attachments if email has none" do
    normalize_and_push(:email)
    conn = conn(:get, "/sent_emails/foo")

    conn = AppRouter.call(conn, nil)

    assert conn.status == 200
    assert detail_pane_attachments_container(conn) == []
  end

  test "shows attachments if email has them" do
    [attachment1, attachment2] =
      attachments = [build(:attachment), build(:attachment, filename: "<b>attach</b>.txt")]

    normalize_and_push(:email, attachments: attachments)
    conn = conn(:get, "/sent_emails/foo")

    conn = AppRouter.call(conn, nil)

    assert conn.status == 200
    assert showing_in_attachments_container?(conn, attachment1)
    assert showing_in_attachments_container?(conn, attachment2)
  end

  test "handles attachment links" do
    attachment = build(:attachment)
    normalize_and_push(:email, attachments: [attachment])
    selected_email_id = SentEmail.all() |> Enum.at(0) |> SentEmail.get_id()
    conn = conn(:get, "/sent_emails/foo/#{selected_email_id}/attachments/0")

    conn = AppRouter.call(conn, nil)

    assert conn.status == 200

    assert {"content-disposition", "inline; filename=\"#{attachment.filename}\""} in conn.resp_headers
  end

  test "shows error if attachment could not be found" do
    normalize_and_push(:email)
    selected_email_id = SentEmail.all() |> Enum.at(0) |> SentEmail.get_id()
    conn = conn(:get, "/sent_emails/foo/#{selected_email_id}/attachments/0")

    conn = AppRouter.call(conn, nil)

    assert conn.status == 404
    assert {"content-type", "text/html; charset=utf-8"} in conn.resp_headers
    assert conn.resp_body =~ "Email not found"
  end

  test "doesn't have double slash if forwarded at root" do
    email = normalize_and_push(:email)
    conn = conn(:get, "/")

    conn = AppRouter.call(conn, nil)

    assert conn.status == 200
    assert {"content-type", "text/html; charset=utf-8"} in conn.resp_headers
    assert conn |> sidebar() |> Floki.raw_html() =~ ~s(href="/#{SentEmail.get_id(email)}")
    assert conn |> sidebar() |> Floki.text() =~ email.subject
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
    selected_email_id = SentEmail.all() |> Enum.at(0) |> SentEmail.get_id()
    unselected_email_id = SentEmail.all() |> Enum.at(1) |> SentEmail.get_id()
    conn = conn(:get, "/sent_emails/foo/#{selected_email_id}")

    conn = AppRouter.call(conn, nil)

    assert conn.status == 200
    assert {"content-type", "text/html; charset=utf-8"} in conn.resp_headers
    assert showing_in_detail_pane?(conn, SentEmail.get(selected_email_id))
    refute showing_in_detail_pane?(conn, SentEmail.get(unselected_email_id))
  end

  test "shows an email's html by id" do
    normalize_and_push_pair(:html_email)
    selected_email_id = SentEmail.all() |> Enum.at(0) |> SentEmail.get_id()
    conn = conn(:get, "/sent_emails/foo/#{selected_email_id}/html")

    conn = AppRouter.call(conn, nil)

    assert conn.status == 200
    assert {"content-type", "text/html; charset=utf-8"} in conn.resp_headers
    assert conn.resp_body =~ SentEmail.get(selected_email_id).html_body
  end

  test "sends an empty body for html emails if html body is nil" do
    normalize_and_push_pair(:email, html_body: nil)
    selected_email_id = SentEmail.all() |> Enum.at(0) |> SentEmail.get_id()
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

  test "shows email metadata when there is no html or text body" do
    email = normalize_and_push(:email, html_body: nil)
    selected_email_id = SentEmail.all() |> Enum.at(0) |> SentEmail.get_id()
    conn = conn(:get, "/sent_emails/foo/#{selected_email_id}")

    conn = AppRouter.call(conn, nil)

    assert conn.status == 200
    assert {"content-type", "text/html; charset=utf-8"} in conn.resp_headers
    assert conn.resp_body =~ "Metadata"
    assert conn.resp_body =~ "#{inspect(email, pretty: true)}"
  end

  test "rewrites CID attachments to local URLs in HTML emails" do
    attachment = build(:attachment, content_id: "abc123")
    email = normalize_and_push(:html_email,
      html_body: ~s(<img src="cid:abc123">),
      attachments: [attachment]
    )
    selected_email_id = SentEmail.get_id(email)
    conn = conn(:get, "/sent_emails/foo/#{selected_email_id}/html")

    conn = AppRouter.call(conn, nil)

    assert conn.status == 200
    assert conn.resp_body =~ ~s(<img src="/sent_emails/#{selected_email_id}/attachments/0">)
  end

  test "leaves non-matching CID references unchanged in HTML emails" do
    attachment = build(:attachment, content_id: "abc123")
    email = normalize_and_push(:html_email,
      html_body: ~s(<img src="cid:xyz789">),
      attachments: [attachment]
    )
    selected_email_id = SentEmail.get_id(email)
    conn = conn(:get, "/sent_emails/foo/#{selected_email_id}/html")

    conn = AppRouter.call(conn, nil)

    assert conn.status == 200
    assert conn.resp_body =~ ~s(<img src="cid:xyz789">)
  end

  test "handles multiple CID attachments in HTML emails" do
    attachments = [
      build(:attachment, content_id: "abc123"),
      build(:attachment, content_id: "def456")
    ]
    email = normalize_and_push(:html_email,
      html_body: ~s(<img src="cid:abc123"><img src="cid:def456">),
      attachments: attachments
    )
    selected_email_id = SentEmail.get_id(email)
    conn = conn(:get, "/sent_emails/foo/#{selected_email_id}/html")

    conn = AppRouter.call(conn, nil)

    assert conn.status == 200
    assert conn.resp_body =~ ~s(<img src="/sent_emails/#{selected_email_id}/attachments/0">)
    assert conn.resp_body =~ ~s(<img src="/sent_emails/#{selected_email_id}/attachments/1">)
  end

  defp newest_email do
    List.first(SentEmail.all())
  end

  defp oldest_email do
    List.last(SentEmail.all())
  end

  defp showing_in_detail_pane?(conn, email) do
    conn |> detail_pane() |> Floki.text() =~ email.subject
  end

  defp detail_pane(conn) do
    conn.resp_body
    |> Floki.parse_document!()
    |> Floki.find(".email-detail-pane")
  end

  defp sidebar(conn) do
    conn.resp_body
    |> Floki.parse_document!()
    |> Floki.find(".email-sidebar")
  end

  defp detail_pane_attachments_container(conn) do
    conn.resp_body
    |> Floki.parse_document!()
    |> Floki.find(".email-detail-pane .email-detail-attachments")
  end

  defp showing_in_attachments_container?(conn, attachment) do
    conn |> detail_pane_attachments_container() |> Floki.text() =~ attachment.filename
  end
end

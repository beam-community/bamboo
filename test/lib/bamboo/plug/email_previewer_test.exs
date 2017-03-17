defmodule Bamboo.EmailPreviewerTest do
  use ExUnit.Case
  use Plug.Test
  import Bamboo.Factory

  defmodule AppRouter do
    use Plug.Router

    plug :match
    plug :dispatch

    forward "/email_previews", to: Bamboo.EmailPreviewPlug
  end

  describe "index" do
    test "shows all the available emails" do
      conn = get("/email_previews")

      assert conn.status == 200
      assert conn.resp_body =~ "Please select an email"
      assert conn.resp_body =~ "Customer Email"
      assert conn.resp_body =~ "Guest Email"
    end
  end

  describe "show" do
    test "renders a valid html email" do
      conn = get("/email_previews/customer_email/html")

      assert conn.resp_body =~ "Hi Customer HTML"
      assert conn.resp_body =~ "View Text Version"
      refute conn.resp_body =~ "View HTML Version"
    end

    test "renders a valid text email" do
      conn = get("/email_previews/guest_email/text")

      assert conn.resp_body =~ "Hi Guest Text"
      assert conn.resp_body =~ "View HTML Version"
      refute conn.resp_body =~ "View Text Version"
    end
  end

  defp get(url) do
    :get
    |> conn(url)
    |> AppRouter.call(nil)
  end
end

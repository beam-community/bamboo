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
    test "renders a valid email" do
      conn = get("/email_previews/customer_email")

      assert conn.resp_body =~ "Hi Customer HTML"
      #assert html_response(conn, 200) =~ "View Text Version"
      #refute html_response(conn, 200) =~ "View HTML Version"
    end
  end

  defp get(url) do
    :get
    |> conn(url)
    |> AppRouter.call(nil)
  end
end

defmodule Bamboo.TestEmailPreview do
  def previews do
    [
      %{
        path: "customer_email",
        name: "Customer Email",
        email: fn ->
          %{html_body: "Hi Customer HTML", text_body: "Hi Customer Text"}
        end,
      }, %{
        path: "guest_email",
        name: "Guest Email",
        email: fn ->
          %{html_body: "Hi Guest HTML", text_body: "Hi Guest Text"}
        end,
      },
    ]
  end
end

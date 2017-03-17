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

  test "shows all the available emails" do
    conn = conn(:get, "/email_previews")

    conn = AppRouter.call(conn, nil)
    assert conn.status == 200
    assert conn.resp_body =~ "Please select an email"
    assert conn.resp_body =~ "Customer Email"
    assert conn.resp_body =~ "Guest Email"
  end
end

defmodule Bamboo.TestEmailPreview do
  def previews do
    [
      %{
        path: "customer_email",
        name: "Customer Email",
      }, %{
        path: "guest_email",
        name: "Guest Email",
      },
    ]
  end
end

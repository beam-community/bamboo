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

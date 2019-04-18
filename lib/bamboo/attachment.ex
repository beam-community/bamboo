defmodule Bamboo.Attachment do
  @moduledoc """
  """

  defstruct filename: nil, content_type: nil, path: nil, data: nil, content_id: nil

  @type t :: %__MODULE__{
          path: nil | String.t(),
          filename: nil | String.t(),
          content_type: nil | String.t(),
          data: nil | binary(),
          content_id: nil | String.t()
        }

  @doc ~S"""
  Creates a new Attachment

  `content_id` can be used to embed an image, attach it and reference it in the message body by
  setting its CID (Content-ID) and using a standard HTML tag:

      <img src="cid:some-image-cid" alt="img" />

  within an HTML email message.

  Examples:

      Bamboo.Attachment.new("/path/to/attachment.png")
      Bamboo.Attachment.new("/path/to/attachment.png", filename: "image.png")
      Bamboo.Attachment.new("/path/to/attachment.png", filename: "image.png", content_type: "image/png", content_id: "12387432")
      Bamboo.Attachment.new(params["file"]) # Where params["file"] is a %Plug.Upload

      email
      |> put_html_layout({LayoutView, "email.html"})
      |> put_attachment(%Bamboo.Attachment{content_type: "image/png", filename: "logo.png", data: "content", content_id: "2343333333"})
  """
  def new(path, opts \\ [])

  if Code.ensure_loaded?(Plug) do
    def new(%Plug.Upload{filename: filename, content_type: content_type, path: path}, opts),
      do: new(path, Keyword.merge([filename: filename, content_type: content_type], opts))
  end

  def new(path, opts) do
    filename = opts[:filename] || Path.basename(path)
    content_type = opts[:content_type] || determine_content_type(path)
    content_id = opts[:content_id]
    data = File.read!(path)

    %__MODULE__{
      path: path,
      data: data,
      filename: filename,
      content_type: content_type,
      content_id: content_id
    }
  end

  defp determine_content_type(path) do
    if Code.ensure_loaded?(Plug) do
      MIME.from_path(path)
    else
      "application/octet-stream"
    end
  end
end

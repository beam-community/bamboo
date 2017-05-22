defmodule Bamboo.Attachment do
  @moduledoc """
  """

  defstruct filename: nil, content_type: nil, path: nil

  @doc ~S"""
  Creates a new Attachment

  Examples:
    Attachment.new("/path/to/attachment.png")
    Attachment.new("/path/to/attachment.png", filename: "image.png")
    Attachment.new("/path/to/attachment.png", filename: "image.png", content_type: "image/png")
    Attachment.new(params["file"]) # Where params["file"] is a %Plug.Upload
  """
  def new(path, opts \\ [])
  if Code.ensure_loaded?(Plug) do
    def new(%Plug.Upload{filename: filename, content_type: content_type, path: path}, opts), do:
      new(path, Dict.merge([filename: filename, content_type: content_type], opts))
  end
  def new(path, opts) do
    filename = opts[:filename] || Path.basename(path)
    content_type = opts[:content_type] || determine_content_type(path)
    %__MODULE__{path: path, filename: filename, content_type: content_type}
  end

  defp determine_content_type(path) do
    if Code.ensure_loaded?(Plug) do
      Plug.MIME.path(path)
    else
      "application/octet-stream"
    end
  end
end

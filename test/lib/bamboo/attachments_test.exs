defmodule Bamboo.AttachmentTest do
  use ExUnit.Case

  alias Bamboo.Attachment

  test "create an attachment" do
    path = Path.join(__DIR__, "../../support/attachment.docx")
    attachment = Attachment.new(path)
    assert attachment.content_type == "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
    assert attachment.filename == "attachment.docx"
    assert attachment.data
  end

  test "create an attachment with an unknown content type" do
    path = Path.join(__DIR__, "../../support/attachment.unknown")
    attachment = Attachment.new(path)
    assert attachment.content_type == "application/octet-stream"
  end

  test "create an attachment with a specified file name" do
    path = Path.join(__DIR__, "../../support/attachment.docx")
    attachment = Attachment.new(path, filename: "my-test-name.doc")
    assert attachment.filename == "my-test-name.doc"
  end

  test "create an attachment with a specified content type" do
    path = Path.join(__DIR__, "../../support/attachment.docx")
    attachment = Attachment.new(path, content_type: "application/msword")
    assert attachment.content_type == "application/msword"
  end

  test "create an attachment from a Plug Upload struct" do
    path = Path.join(__DIR__, "../../support/attachment.docx")
    upload = %Plug.Upload{filename: "test.docx",
                          content_type: "application/msword",
                          path: path}
    attachment = Attachment.new(upload)
    assert attachment.content_type == "application/msword"
    assert attachment.filename == "test.docx"
    assert attachment.data
  end

  test "create an attachment from a Plug Upload struct with overrides" do
    path = Path.join(__DIR__, "../../support/attachment.docx")
    upload = %Plug.Upload{filename: "test.docx",
                          content_type: "application/msword",
                          path: path}
    attachment = Attachment.new(upload, filename: "my-attachment.doc", content_type: "application/other")
    assert attachment.content_type == "application/other"
    assert attachment.filename == "my-attachment.doc"
    assert attachment.data
  end
end

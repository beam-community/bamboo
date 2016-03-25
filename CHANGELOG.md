## 0.4.0

### New Additions

* `EmailPreviewPlug` for previewing emails in development.
* Improved documentation with more and better examples.

### Breaking Changes

* `MandrillEmail` has been renamed to `MandrillHelper`. The API is the same so all you will have to do is rename your imports and/or aliases.
* `Mailer.deliver/1` has been renamed to `Mandrill.deliver_now/1` to add clarity. See discussion here: https://github.com/paulcsmith/bamboo/issues/89

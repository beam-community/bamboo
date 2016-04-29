## 0.5.0

### New Additions

* Much improved test helpers ([#109])
* `Bamboo.TaskSupervisorStrategy` is now started by default ([#133])
* New Mailgun adapter ([#125])
* Link to new Sparkpost adapter ([#118])
* Shared mode for working with multiple process/acceptance tests ([#136])
* New `Bamboo.Phoenix.put_layout/2` for setting HTML and text layouts at the same time ([#122])

### Fixes

* Show correct "from" address in `EmailPreview` ([#127])

### Breaking changes

* `Bamboo.Test.assert_no_emails_sent` has been renamed to
  `assert_no_emails_delivered` ([#109])
* Since `Bamboo.TaskSupervisorStrategy` is started automatically,    
  `Bamboo.TaskSupervisorStrategy.child_spec` has been removed. Please remove
  the call to that function from your `lib/my_app.ex` file.

[#109]: https://github.com/thoughtbot/bamboo/pull/109/files
[#133]: https://github.com/thoughtbot/bamboo/pull/133/files
[#125]: https://github.com/thoughtbot/bamboo/pull/125/files
[#118]: https://github.com/thoughtbot/bamboo/pull/118/files
[#136]: https://github.com/thoughtbot/bamboo/pull/136/files
[#122]: https://github.com/thoughtbot/bamboo/pull/122/files
[#127]: https://github.com/thoughtbot/bamboo/pull/127/files

## 0.4.2

### New Additions

* Add `Bamboo.SendgridAdapter`
* Improve and update docs

## 0.4.1

### New Additions

* Improve docs

## 0.4.0

### New Additions

* `EmailPreviewPlug` for previewing emails in development.
* Improved documentation with more and better examples.

### Breaking Changes

* `MandrillEmail` has been renamed to `MandrillHelper`. The API is the same so all you will have to do is rename your imports and/or aliases.
* `Mailer.deliver/1` has been renamed to `Mandrill.deliver_now/1` to add clarity. See discussion here: https://github.com/paulcsmith/bamboo/issues/89

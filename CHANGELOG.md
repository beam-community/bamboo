## 0.8.0

### New Additions

* Add helper for working with Mandrill merge vars ([#219])
* Show header in email preview ([#225])
* Add SendGrid template support ([#163])
* Add `Bamboo.Test.assert_delivered_with` for more fine grained assertions ([#228])
* Add Mailgun header support ([#235])

### Fixes/Enhancements

* Drop dependency on HTTPoison and use Hackney directly ([#201])
* Remove warnings and deprecations for Elixir 1.4 ([#240], [#241])

[#201]: https://github.com/thoughtbot/bamboo/pull/201
[#219]: https://github.com/thoughtbot/bamboo/pull/219
[#225]: https://github.com/thoughtbot/bamboo/pull/225
[#163]: https://github.com/thoughtbot/bamboo/pull/163
[#228]: https://github.com/thoughtbot/bamboo/pull/228
[#235]: https://github.com/thoughtbot/bamboo/pull/235
[#240]: https://github.com/thoughtbot/bamboo/pull/240
[#241]: https://github.com/thoughtbot/bamboo/pull/241

## 0.7.0

### New Additions

* Add example of using HTML layouts with Bamboo.Phoenix ([#173])
* Give suggestions for why email preview may not be working ([#177])
* Add Mandrill template support ([#176])

### Fixes/Enhancements

* Build mailer config during runtime. Allows for configuratin with Conform ([#170])
* Fix "leaking" HTML email styles ([#172])
* Catch `nil` email addresses when used in 2-item tuple ([#151])
* Remove `ExMachina` from dev/prod deps. It should have been a test only dep ([#198])
* Small typo fixes ([#199])
* Explicitly set content type in email preview so that HTML emails are always preview as HTML ([#203] and [#204])

[#170]: https://github.com/thoughtbot/bamboo/pull/170
[#173]: https://github.com/thoughtbot/bamboo/pull/173
[#177]: https://github.com/thoughtbot/bamboo/pull/177
[#172]: https://github.com/thoughtbot/bamboo/pull/172
[#191]: https://github.com/thoughtbot/bamboo/pull/191
[#151]: https://github.com/thoughtbot/bamboo/pull/151
[#176]: https://github.com/thoughtbot/bamboo/pull/176
[#198]: https://github.com/thoughtbot/bamboo/pull/198
[#199]: https://github.com/thoughtbot/bamboo/pull/199
[#203]: https://github.com/thoughtbot/bamboo/pull/203
[#204]: https://github.com/thoughtbot/bamboo/pull/204

## 0.6.0

### New Additions

* Improved error message when mailer config is invalid ([#148])
* Added typespecs to many modules and functions ([#150], [#164])
* Strip assigns from the email when testing. Makes testing more reliable ([#158])

[#148]: https://github.com/thoughtbot/bamboo/pull/148
[#150]: https://github.com/thoughtbot/bamboo/pull/150
[#164]: https://github.com/thoughtbot/bamboo/pull/164
[#158]: https://github.com/thoughtbot/bamboo/pull/158

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

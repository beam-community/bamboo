## [1.3.0] - 2019-08-02

### New Additions
* Add support for SendGrid's `asm_group_id` ([#457]) 
* Add `SentEmailApiPlug` ([#456]) 
* Add ability to bypass list management for SendGrid Adapter ([#458], [#463])
* Add `supports_attachments?` to adapter behaviour ([#410])
* Allow setting of Mailgun config from env ([#363])
* Add option to `deliver_now` to return adapter response ([#466])
* SendGrid Adapter Reply-To parameter updates ([#487])
* Google Analytics settings for SendGrid Adapter ([#462])
* Add support for Mailgun tags and templates ([#490])
* Config driven `base_uri` for Mailgun Adapter ([#491])

### Fixes/Enhancements
* Fix typos and documentation ([#454], [#447], [#455], [#461], [#468], [#473], [#488])
* Add additional adapters to README ([#446], [#480])
* Add .t() spec type to `Bamboo.Attachment` ([#389])
* Add Elixir code formatter ([#464])
* Clarify changes and test phases in mailer test ([#465])
* Restructure/update README ([#467])
* Add Code of Conduct ([#471])
* Replace Poison with Jason for json encoding/decoding ([#485])
* Upgrade ex_doc ([#486])
* Remove whitespaces inside `pre` tag in `SentEmailViewer` ([#493]) 
* Use a formatter for `assert_email_delivered_with/1` ([#482])

[#457]: https://github.com/thoughtbot/bamboo/pull/457
[#456]: https://github.com/thoughtbot/bamboo/pull/456
[#458]: https://github.com/thoughtbot/bamboo/pull/458
[#463]: https://github.com/thoughtbot/bamboo/pull/463
[#410]: https://github.com/thoughtbot/bamboo/pull/410
[#363]: https://github.com/thoughtbot/bamboo/pull/363
[#466]: https://github.com/thoughtbot/bamboo/pull/466
[#487]: https://github.com/thoughtbot/bamboo/pull/487
[#462]: https://github.com/thoughtbot/bamboo/pull/462
[#490]: https://github.com/thoughtbot/bamboo/pull/490
[#491]: https://github.com/thoughtbot/bamboo/pull/491
[#454]: https://github.com/thoughtbot/bamboo/pull/454
[#447]: https://github.com/thoughtbot/bamboo/pull/447
[#455]: https://github.com/thoughtbot/bamboo/pull/455
[#461]: https://github.com/thoughtbot/bamboo/pull/461
[#468]: https://github.com/thoughtbot/bamboo/pull/468
[#473]: https://github.com/thoughtbot/bamboo/pull/473
[#488]: https://github.com/thoughtbot/bamboo/pull/488
[#446]: https://github.com/thoughtbot/bamboo/pull/446
[#480]: https://github.com/thoughtbot/bamboo/pull/480
[#389]: https://github.com/thoughtbot/bamboo/pull/389
[#464]: https://github.com/thoughtbot/bamboo/pull/464
[#465]: https://github.com/thoughtbot/bamboo/pull/465
[#467]: https://github.com/thoughtbot/bamboo/pull/467
[#471]: https://github.com/thoughtbot/bamboo/pull/471
[#485]: https://github.com/thoughtbot/bamboo/pull/485
[#486]: https://github.com/thoughtbot/bamboo/pull/486
[#493]: https://github.com/thoughtbot/bamboo/pull/493
[#482]: https://github.com/thoughtbot/bamboo/pull/482

## [1.2.0] - 2019-01-30

### New Additions

* Allow custom args for SendGrid (https://github.com/thoughtbot/bamboo/pull/413)
* Added support for dynamic template data in Sendgrid ((https://github.com/thoughtbot/bamboo/pull/426)

### Fixes/Enhancements

* Make JSON library configurable (https://github.com/thoughtbot/bamboo/pull/374)
* Fix reply-to header being set as string for mailgun adapter (https://github.com/thoughtbot/bamboo/pull/421)
* Fix HTML escaping in headers (https://github.com/thoughtbot/bamboo/pull/437)
* Fix Sendgrid sandbox mode (https://github.com/thoughtbot/bamboo/pull/442)
* Lazily render debug logs (https://github.com/thoughtbot/bamboo/pull/438)

## [1.1.0] - 2018-08-15

### Fixes/Enhancements

* Update hackney version requirement to 1.13.0
* README improvements
* Migrate circleci configuration to 2.0 (https://github.com/thoughtbot/bamboo/pull/411)

## [1.0.0] - 2018-06-14

### New Additions

* Support attachments in SendGridAdapter (https://github.com/thoughtbot/bamboo/pull/294)
* Mailgun attachment support (https://github.com/thoughtbot/bamboo/pull/341)
* Bamboo logo (https://github.com/thoughtbot/bamboo/pull/388)

### Fixes/Enhancements

* Convert send_grid_adapter to SendGrid API v3 (https://github.com/thoughtbot/bamboo/pull/293)
* Fix collapsing html email preview (https://github.com/thoughtbot/bamboo/pull/351)
* Misc dependency version updates

## [1.0.0-rc2] - 2017-11-03

### New Additions

* Add support to Mailgun adapter for using custom vars (https://github.com/thoughtbot/bamboo/pull/306)
* Add option to open a browser window for every new email (https://github.com/thoughtbot/bamboo/pull/222)
* Display Sender's name on the preview page (https://github.com/thoughtbot/bamboo/pull/277)

### Fixes/Enhancements

* Support file data in attachment struct + mailgun attachment support (https://github.com/thoughtbot/bamboo/pull/292)
* Fix compilation warnings (https://github.com/thoughtbot/bamboo/pull/304)
* Remove deprecated call (https://github.com/thoughtbot/bamboo/pull/321)
* Differentiate master/published SendGridHelper link (https://github.com/thoughtbot/bamboo/pull/325)
* Misc README improvements

## [1.0.0-rc.1] - 2017-05-05

### New Additions

* Bamboo allows adapters to support attachments! (https://github.com/thoughtbot/bamboo/pull/156)
* Add `MailgunAdapter` attachment support (https://github.com/thoughtbot/bamboo/commit/d47833194833e6a1cb9f9cb715be0742e55f5fd8)
* Add support for `replyto` header in `SendGridAdapter` (https://github.com/thoughtbot/bamboo/pull/254)
* Raise if email has attachments and adapter doesn't support them (https://github.com/thoughtbot/bamboo/commit/ce2249c9854a79148ecf91f877ae26142c83184b)

### Fixes/Enhancements

* Force correct mime type in preview (https://github.com/thoughtbot/bamboo/commit/e6f5389314193ef75a015d49a8a6e23b08bc281a)
* Update Hackney to fix header issues (https://github.com/thoughtbot/bamboo/pull/263)
* Adds `Bamboo.ApiError` that can be used by adapters (https://github.com/thoughtbot/bamboo/commit/2876dfeea0911fc51c9fa3daae0dbc7a17ca0557)
* Numerous small updates and fixes to documentation and README.

### Breaking changes

* Renamed `SendgridAdapter/Helper` to `SendGridAdapter/Helper` (https://github.com/thoughtbot/bamboo/commit/6b582f80781f0072bd4051084a3286991bfde2d0)
* Change `assert_delivered_with` to `assert_email_delivered_with` (https://github.com/thoughtbot/bamboo/commit/9823793fbcd45c2a58ef9bd1e65e5d162625513e)
* Renamed `EmailPreviewPlug` to `SentEmailViewerPlug` (https://github.com/thoughtbot/bamboo/commit/f3668458f13e0a018eebbe38681362144292cd25)

## [0.8.0] - 2017-01-06

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

## [0.7.0] - 2016-07-29

### New Additions

* Add example of using HTML layouts with Bamboo.Phoenix ([#173])
* Give suggestions for why email preview may not be working ([#177])
* Add Mandrill template support ([#176])

### Fixes/Enhancements

* Build mailer config during runtime. Allows for configuration with Conform ([#170])
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

[1.3.0]: https://github.com/thoughtbot/bamboo/compare/v1.2.0...v1.3.0
[1.2.0]: https://github.com/thoughtbot/bamboo/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/thoughtbot/bamboo/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/thoughtbot/bamboo/compare/v1.0.0-rc2...v1.0.0
[1.0.0-rc2]: https://github.com/thoughtbot/bamboo/compare/v1.0.0-rc.1...v1.0.0-rc2
[1.0.0-rc.1]: https://github.com/thoughtbot/bamboo/compare/v0.8.0...v1.0.0-rc.1
[0.8.0]: https://github.com/thoughtbot/bamboo/compare/v0.7.0...v0.8.0
[0.7.0]: https://github.com/thoughtbot/bamboo/releases/tag/v0.7.0

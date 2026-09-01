qbx_garagesでは試していない。
AI挙動があんまりよくない。



# oph3z-phone App Template

This is a starter kit for building your own app for [**oph3z-phone**](https://github.com/Oph3Z1/oph3z-phone). Copy the
folder, change a few names, and you already have a working app on the phone. From
there you edit the web files to make it yours.

You never touch the phone's code. Your app is a completely separate FiveM resource
that just tells the phone "here I am." The phone puts your icon on the home screen
and shows your page inside itself. You can build that page however you like: plain
HTML/CSS/JS (that's what this template uses), or React, Vue, Tailwind,
whatever you are comfortable with.

If you have never made a phone app before, read this top to bottom once. It is
written to be followed step by step.



## How it works (the short version)

Three things happen:

1. Your resource starts and calls one export to **register** the app (icon + name).
2. The phone shows your icon. When the player opens it, the phone loads your
   `ui/index.html` **inside an iframe** (a little window inside the phone screen).
3. Your page and the phone talk to each other with messages. The phone tells your
   page who the player is; your page can ask the phone to close, show a popup, send
   a notification, and so on.



## Requirements

**oph3z-phone** installed and started. That is the only requirement.


## Documentation
The Gitbook page contains detailed information about this template and everything you need to know about how to use it (functions, etc.):
[Gitbook](https://oph3zdev.gitbook.io/docs/free/phone/third-party-apps)

## Common problems

**The icon never shows up.** Make sure your resource starts *after* `oph3z-phone`
in `server.cfg`, and that your `Config.App.id` is not the same as another app.

**The page is blank inside the phone.** Check the `ui` path in `config.lua` and make
sure the file is listed under `files` in `fxmanifest.lua`. A typo in either one
leaves you with an empty iframe.

**A full-screen page covers everything, even with the phone closed.** You added
`ui_page` to the manifest. Remove it. The phone loads your page for you.

**The notification button does nothing.** The event names in `client.lua` and
`server.lua` have to match each other. If you renamed the resource, double-check
both are still spelled the same.

**An ShareDrop or share never arrives.** The receiver has to have ShareDrop turned on
(in Control Center) and be close enough (inside `Config.Sharedrop.Range` on the
phone). They also need the same app installed. If they don't, the sender is told.


## License and usage

This template is a starting point, so treat it like one. Use it, change it, and
ship whatever you build on top of it. A credit back to oph3z-phone is appreciated
but not required. Please don't repackage the template itself and sell it as your own
starter kit.

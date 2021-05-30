HACK: merged icons
==================

This hack serves as a big workaround for applications that just falls back to
`hicolor` without looking at another fallback theme first when an icon is
missing.

This currently serves to workaround those bugs:

 - https://bugs.kde.org/show_bug.cgi?id=435236

But it turns out that this is also useful as a general way to force an icon
theme to work without involving user-side configuration. ¯\\\_(ツ)\_/¯

You can observe the usefulness of this hack by using Plasma Mobile apps, e.g.
*Alligator* or *Angelfish*, under *Phosh*. Without this hack they will be
missing some icons. With this hack, they will be using icons, and if used
wihout additional themes, and removing legacy icons, will even fallback to
the breeze theme!


Usage
-----

Example usage:

```nix
# configuration.nix
{ pkgs, ... }:

{
  imports = [
    .../hack-merged-icons/module.nix
  ];

  hacks.mergedIcons = {
    enable = true;
    disabledThemes = [
      "Adwaita"
    ];
    iconThemes = [
      # Desired theme
      "${pkgs.pantheon.elementary-icon-theme}/share/icons/elementary"
    ];
    removeLegacyIcons = true;
  };
}
```

> **NOTE**: by default both *Adwaita* and *Breeze* are included in fallback
> themes. Additionally this, by default, masquerades as `hioclor`. This means
> that by default icons should always resolve when using this.


Upstreaming
-----------

This is probably not something that can be upstreamed into NixOS.

It is a *huuuuuuge* hack.

Additionally, I guess Ruby in the system build wouldn't be welcomed.

{ lib
, runCommandNoCC
, ruby
, hicolor-icon-theme
# List of themes to add to the merged set.
# The latter icon themes are preferred.
, iconThemes
, themeName
, removeLegacyIcons ? false
}:

runCommandNoCC "merged-icons" {
  nativeBuildInputs = [
    ruby
  ];
  hicolor = hicolor-icon-theme;
  inherit iconThemes themeName removeLegacyIcons;
  meta.priority = 2;
} ''
  ruby ${./merge-icons.rb}
''

{ config, pkgs, lib, ... }:

let
  cfg = config.hacks.mergedIcons;

  # Fallback icons can't be re-ordered.
  # So if a user *desires* Adwaita to be preferred to Breeze, they need to
  # add Adwaita to their own theme stack.
  iconThemes = [
  ] ++ lib.optionals cfg.fallback.adwaita [
    # Fallback for GNOME
    "${pkgs.gnome.adwaita-icon-theme}/share/icons/Adwaita"
  ] ++ lib.optionals cfg.fallback.breeze [
    # Fallback for Plasma
    "${pkgs.breeze-icons}/share/icons/breeze-dark"
    "${pkgs.breeze-icons}/share/icons/breeze"
  ] ++ cfg.iconThemes;

  merged-icons = pkgs.callPackage ./merged-icons.nix {
    inherit (cfg) themeName removeLegacyIcons;
    inherit iconThemes;
  };

  masqueradeAs = cfg.masqueradeAs
    ++ (lib.optional cfg.masqueradeAsHiColor "hicolor")
  ;

  # Sinkhole a given theme
  sinkholeTheme = theme: (pkgs.runCommandNoCC "icon-theme-sinkhole-${theme}" { meta.priority = 1; } ''
    mkdir -p $out/share/icons/${theme}
    ln -sf /dev/null $out/share/icons/${theme}/index.theme
  '');
in
{
  options = {
    hacks = {
      mergedIcons = {
        enable = lib.mkEnableOption "merged icons hack";
        iconThemes = lib.mkOption {
          description = ''
            Icon themes do merge.

            The icon theme 
          '';
          type = with lib.types; listOf path;
        };
        themeName = lib.mkOption {
          type = lib.types.str;
          default = "merged-icons";
          description = ''
            Name of the generated theme.

            Useful if you want to change the default.
          '';
        };
        masqueradeAs = lib.mkOption {
          type = with lib.types; listOf str;
          default = [];
          description = ''
            Additional theme names the merged theme pretends to be.
          '';
        };
        masqueradeAsHiColor = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = ''
            Whether to replace *hicolor* with the merged icon theme.
          '';
        };
        fallback =
          let
            mkFallbackOption = name: lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = "Whether to enable ${name} as fallback icons";
            };
          in
        {
            adwaita = mkFallbackOption "Adwaita, the default GNOME theme,";
            breeze  = mkFallbackOption "Breeze, the default Plasma theme,";
        };
        disabledThemes = lib.mkOption {
          type = with lib.types; listOf str;
          default = [];
          description = ''
            Unqualified theme directories to disable by cloberring `index.theme`.

            It is unlikely you want to disable `hicolor`.
          '';
        };
        removeLegacyIcons = lib.mkEnableOption "removing legacy icons from the merged theme";
      };
    };
  };
  config = lib.mkIf cfg.enable {
    environment.systemPackages = lib.mkAfter (
      [
        merged-icons
      ]
      ++ (map (themeName: (merged-icons.override({ inherit themeName; }))) masqueradeAs)
      ++ (map sinkholeTheme cfg.disabledThemes)
    );
    system.extraSystemBuilderCmds = ''
    '';
  };
}

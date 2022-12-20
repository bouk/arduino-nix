{ lib, pkgs }:
let
  wrap = {
    packages ? []
    , libraries ? []
  }:
  let
    inherit (pkgs.callPackage ./lib.nix {}) latestVersion;

    builtinPackages = (map latestVersion (builtins.attrValues pkgs.arduinoPackages.tools.builtin));

    userPath = pkgs.symlinkJoin {
      name = "arduino-libraries";
      paths = libraries;
    };

    dataPath = pkgs.symlinkJoin {
      name = "arduino-data";
      paths = builtinPackages ++ packages ++ [
        # Add some dummy files to keep the CLI happy
        (pkgs.writeTextDir "inventory.yaml" (builtins.toJSON {}))
        (pkgs.writeTextDir "package_index.json" (builtins.toJSON {packages = [];}))
        (pkgs.writeTextDir "library_index.json" (builtins.toJSON {libraries = [];}))
      ];
    };
  in
    pkgs.runCommand "arduino-cli-wrapped" {
      buildInputs = [ pkgs.makeWrapper ];
      meta.mainProgram = "arduino-cli";
      passthru = {
        inherit dataPath userPath;
      };
    } ''
      makeWrapper ${pkgs.arduino-cli}/bin/arduino-cli $out/bin/arduino-cli --set ARDUINO_UPDATER_ENABLE_NOTIFICATION false --set ARDUINO_DIRECTORIES_DATA ${dataPath} --set ARDUINO_DIRECTORIES_USER ${userPath}
    '';
in
  lib.makeOverridable wrap


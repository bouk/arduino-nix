# arduino-nix

A flake that allows building an `arduino-cli` environment with certain packages and libraries pre-installed.

## Example

You need to provide a package index and library index to use `arduino-nix`. You can find some at [arduino-indexes](https://github.com/bouk/arduino-indexes).

Alternatively, you can download them at https://downloads.arduino.cc/packages/package_index.json and https://downloads.arduino.cc/libraries/library_index.json

From the indexes you create overlays which then make the Arduino packages and libraries available for the wrapArduinoCLI function provided by this flake.

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    arduino-nix.url = "github:bouk/arduino-nix";
    arduino-library-index = {
      url = "github:bouk/arduino-indexes/library_index";
      flake = false;
    };
    arduino-package-index = {
      url = "github:bouk/arduino-indexes/package_index";
      flake = false;
    };
    arduino-package-rp2040-index = {
      url = "github:bouk/arduino-indexes/package_rp2040_index";
      flake = false;
    };
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    arduino-nix,
    arduino-package-index,
    arduino-package-rp2040-index,
    arduino-library-index,
    ...
  }@attrs:
  let
    overlays = [
      (arduino-nix.overlay)
      (arduino-nix.mkArduinoPackageOverlay (arduino-package-index + "/package_index.json"))
      (arduino-nix.mkArduinoPackageOverlay (arduino-package-rp2040-index + "/package_rp2040_index.json"))
      (arduino-nix.mkArduinoLibraryOverlay (arduino-library-index + "/library_index.json"))
    ];
  in
  (flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = (import nixpkgs) {
          inherit system overlays;
        };
      in rec {
        packages.arduino-cli = pkgs.wrapArduinoCLI {
          libraries = with pkgs.arduinoLibraries; [
            (arduino-nix.latestVersion ADS1X15)
            (arduino-nix.latestVersion Ethernet_Generic)
            (arduino-nix.latestVersion SCL3300)
            (arduino-nix.latestVersion TMCStepper)
            (arduino-nix.latestVersion pkgs.arduinoLibraries."Adafruit PWM Servo Driver Library")
          ];

          packages = with pkgs.arduinoPackages; [
            platforms.arduino.avr."1.6.23"
            platforms.rp2040.rp2040."2.3.3"
          ];
        };
      }
    ));
}
```
## Fix-ups for specific platforms

Some platform packages need fix-ups to work usefully; this can often be done by overriding the derivation for the platform package. Platforms that are currently known to need this are documented in this section.

### esp8266

The esp8266 core package has some convoluted code around enabling and disabling "aggressive core caching"; this seems to rely on a file `cores/esp8266/CommonHFile.h` either already existing or being created on first use. Obviously the nix store is read-only so this must be done when the derivation for the package is built:
```
  ...
  packages = with pkgs.arduinoPackages; [
    (platforms.esp8266.esp8266."3.1.2".overrideAttrs {
      postInstall = "touch $out/$dirName/cores/esp8266/CommonHFile.h";
    })
  ]
  ...
```

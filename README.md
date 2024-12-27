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
    arduino-index = {
      url = "github:bouk/arduino-indexes";
      flake = false;
    };
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    arduino-nix,
    arduino-index,
    ...
  }@attrs:
  let
    overlays = [
      (arduino-nix.overlay)
      (arduino-nix.mkArduinoPackageOverlay (arduino-index + "/index/package_index.json"))
      (arduino-nix.mkArduinoPackageOverlay (arduino-index + "/index/package_rp2040_index.json"))
      (arduino-nix.mkArduinoLibraryOverlay (arduino-index + "/index/library_index.json"))
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

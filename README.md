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

        // arduinoEnv provides bin/arduino-cli and some useful helpers functions
        arduinoEnv = pkgs.makeArduinoEnv {
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
      in rec {
        packages = {
          inherit arduinoEnv;

          my-rp2020-project = arduinoEnv.buildArduinoSketch {
            name = "my-rp2040-project";
            src = ./. + "/my-rp2040-project";
            fqbn = "arduino:mbed_rp2040:pico";
          };
      }
    ));
}
```

## Interactive arduino-cli usage:

```
nix develop .#arduinoEnv
```

## Build Arduino Sketch

```
nix build .#my-rp2040-project
```

Now you have `result` in your current working directory containing the compile outputs.

## Upload to board

```
nix run .#my-rp2040-project.uploadArduinoSketch -- -p /dev/ttyUSB0
```

This with upload the sketch via serial on `/dev/ttyUSB0`.
You can append any additional options from `arduino-cli upload` after `--`.
It uses the same fqbn as specified in `buildArduinoSketch`.

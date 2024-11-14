{
  description = "Wrapper for arduino-cli";

  outputs = { self }: {
    mkArduinoPackageOverlay = { packageIndexFile, buildProperties ? {} }: (self: super: {
      arduinoPackages = self.lib.recursiveUpdate (super.arduinoPackages or {}) (self.callPackage ./packages.nix {
        packageIndex = builtins.fromJSON (builtins.readFile packageIndexFile);
        buildProperties = buildProperties;
      });
    });

    mkArduinoLibraryOverlay = libraryIndexFile: (self: super: {
      arduinoLibraries = self.lib.recursiveUpdate (super.arduinoLibraries or {}) (self.callPackage ./libraries.nix {
        libraryIndex = builtins.fromJSON (builtins.readFile libraryIndexFile);
      });
    });

    overlay = (self: super: {
      wrapArduinoCLI = self.callPackage ./wrap-arduino-cli.nix { };
    });

    # Expose helper to select package
    latestVersion = (import ./lib.nix { lib = null; }).latestVersion;
  };
}

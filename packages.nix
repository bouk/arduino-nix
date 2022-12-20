# From tools.go in arduino-cli
#	regexpLinuxArm   = regexp.MustCompile("arm.*-linux-gnueabihf")
#	regexpLinuxArm64 = regexp.MustCompile("(aarch64|arm64)-linux-gnu")
#	regexpLinux64    = regexp.MustCompile("x86_64-.*linux-gnu")
#	regexpLinux32    = regexp.MustCompile("i[3456]86-.*linux-gnu")
#	regexpWindows32  = regexp.MustCompile("i[3456]86-.*(mingw32|cygwin)")
#	regexpWindows64  = regexp.MustCompile("(amd64|x86_64)-.*(mingw32|cygwin)")
#	regexpMac64      = regexp.MustCompile("x86_64-apple-darwin.*")
#	regexpMac32      = regexp.MustCompile("i[3456]86-apple-darwin.*")
#	regexpMacArm64   = regexp.MustCompile("arm64-apple-darwin.*")
#	regexpFreeBSDArm = regexp.MustCompile("arm.*-freebsd[0-9]*")
#	regexpFreeBSD32  = regexp.MustCompile("i?[3456]86-freebsd[0-9]*")
#	regexpFreeBSD64  = regexp.MustCompile("amd64-freebsd[0-9]*")

{ fetchzip, stdenv, lib, packageIndex, pkgsBuildHost, pkgs, arduinoPackages }:

with builtins;
let
  inherit (pkgsBuildHost.xorg) lndir;
  inherit (pkgs.callPackage ./lib.nix {}) selectSystem convertHash;

  # Tools are installed in $platform_name/tools/$name/$version
  tools = listToAttrs (map ({ name, tools, ... }: {
    inherit name;
    value = let platformName = name; in mapAttrs (_: versions: listToAttrs (map ({name, version, systems, ...}: {
      name = version;
      value = let
        system = selectSystem stdenv.hostPlatform.system systems;
      in
        if system == null then
          throw "Unsupported platform ${stdenv.hostPlatform.system}"
        else
          stdenv.mkDerivation {
            pname = "${platformName}-${name}";
            inherit version;

            dirName = "packages/${platformName}/tools/${name}/${version}";
            installPhase = ''
              mkdir -p "$out/$dirName"
              cp -R * "$out/$dirName/"
            '';
            nativeBuildInputs = [ pkgs.unzip ];
            src = fetchurl ({
              url = system.url;
            } // (convertHash system.checksum));
          };
    }) versions)) (groupBy ({ name, ... }: name) tools);
  }) packageIndex.packages);
    
  # Platform are installed in $platform_name/hardware/$architecture/$version
  platforms = listToAttrs (map ({ name, platforms, ... }: {
    inherit name;
    value = mapAttrs (architecture: versions: listToAttrs (map ({version, url, checksum, toolsDependencies ? [], ...}: {
      name = version;
      value = stdenv.mkDerivation {
        pname = "${name}-${architecture}";
        inherit version;
        dirName = "packages/${name}/hardware/${architecture}/${version}";

        toolsDependencies = map ({packager, name, version}: arduinoPackages.tools.${packager}.${name}.${version}) toolsDependencies;
        passAsFile = [ "toolsDependencies" ];
        installPhase = ''
          mkdir -p "$out/$dirName"
          cp -R * "$out/$dirName/"

          for i in $(cat $toolsDependenciesPath); do
            ${lndir}/bin/lndir -silent $i $out
          done
        '';
        nativeBuildInputs = [ pkgs.unzip ];
        src = fetchurl ({
          url = url;
        } // (convertHash checksum));
      };
    }) versions)) (groupBy ({ architecture, ... }: architecture) platforms);
  }) packageIndex.packages);
in
{
  inherit tools platforms;
}

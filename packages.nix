{ fetchzip, stdenv, lib, packageIndex, buildProperties, pkgsBuildHost, pkgs, arduinoPackages }:

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
          runHook preInstall

          mkdir -p "$out/$dirName"
          cp -R * "$out/$dirName/"

          for i in $(cat $toolsDependenciesPath); do
            ${lndir}/bin/lndir -silent $i $out
          done

          runHook postInstall
        '';
        patchPhase = ''
        # Iterate over each key-value pair in buildProperties
        ${
          pkgs.lib.concatStringsSep "\n" (pkgs.lib.mapAttrsToList (key: value: ''
            sed -i "s|^${key}=.*|${key}=\"${value}\"|" "$out/$dirName/platform.txt"
          '') buildProperties)
        }
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

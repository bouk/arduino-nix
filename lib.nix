{ lib }:
let
  alt = a: b: if a == null then b else a;
in
with builtins; rec {
  latestVersion = attrs: (builtins.head (builtins.sort (a: b: (builtins.compareVersions a.version b.version) == 1) (builtins.attrValues (builtins.mapAttrs (version: value: { inherit version value; }) attrs)))).value;
  selectSystem = system: systems:
    if system == "aarch64-darwin" then
      alt (lib.findFirst ({host, ...}: (match "arm64-apple-darwin.*" host) != null) null systems) (selectSystem "x86_64-darwin" systems)
    else if system == "x86_64-darwin" then
      alt (lib.findFirst ({host, ...}: (match "x86_64-apple-darwin.*" host) != null) null systems) (selectSystem "i686-darwin" systems)
    else if system == "i686-darwin" then
      lib.findFirst ({host, ...}: (match "i[3456]86-apple-darwin.*" host) != null) null systems
    else if system == "aarch64-linux" then
      lib.findFirst ({host, ...}: (match "(aarch64|arm64)-linux-gnu" host) != null) null systems
    else if system == "x86_64-linux" then
      lib.findFirst ({host, ...}: (match "x86_64-.*linux-gnu" host) != null) null systems
    else null;
  convertHash = hash: let
    m = (match "(SHA-256|SHA-1|MD5):(.*)" hash);
    algo = elemAt m 0;
    h = elemAt m 1;
  in
    if m == null then
      throw "Unsupported hash format ${hash}"
    else if algo == "SHA-256" then
      { sha256 = h; }
    else if algo == "SHA-1" then
      { sha1 = h; }
    else
      { md5 = h; };
}

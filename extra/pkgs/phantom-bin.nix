# Minecraft LAN proxy for game consoles (binary distribution)
# Downloads the pre-built Linux binary from GitHub releases rather than compiling from source
# The binary is statically linked and works on NixOS without patching

# For the time being I am not going to explain how to write nix packages,
# As it is outside of the configuration scope

{
  lib,
  stdenv,
  fetchurl,
}:
let
  version = "0.5.4";
in
stdenv.mkDerivation {
  pname = "phantom-bin";
  inherit version;

  src = fetchurl {
    url = "https://github.com/jhead/phantom/releases/download/v${version}/phantom-linux";
    hash = "sha256-hncnGsCysZt+qLUmMx3cpr9elakerD3YWIt4cegQse0=";
  };

  dontUnpack = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin
    install -m755 $src $out/bin/phantom

    runHook postInstall
  '';

  meta = with lib; {
    description = "A LAN proxy for connecting game consoles to remote Minecraft servers.";
    homepage = "https://github.com/jhead/phantom";
    license = licenses.mit;
    platforms = [ "x86_64-linux" ];
    maintainers = with maintainers; [ Jamesx86-64 ];
    mainProgram = "phantom-linux";
  };
}

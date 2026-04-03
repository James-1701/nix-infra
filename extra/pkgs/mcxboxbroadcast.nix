{
  lib,
  stdenv,
  fetchurl,
  jre,
  makeWrapper,
}:

let
  jarFile = fetchurl {
    url = "https://github.com/MCXboxBroadcast/Broadcaster/releases/latest/download/MCXboxBroadcastStandalone.jar";
    hash = "sha256-2WInwvL+aLnh7T5g1fek2W9ZTWCC2Zc2p3fBUZ1lOMc=";
  };
in
stdenv.mkDerivation {
  pname = "mcxboxbroadcast";
  version = "latest";

  dontUnpack = true;

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    mkdir -p $out/share/mcxboxbroadcast $out/bin
    cp ${jarFile} $out/share/mcxboxbroadcast/MCXboxBroadcastStandalone.jar

    makeWrapper ${jre}/bin/java $out/bin/mcxboxbroadcast \
      --add-flags "-jar $out/share/mcxboxbroadcast/MCXboxBroadcastStandalone.jar"
  '';

  meta = {
    description = "Broadcasts a Geyser/Bedrock server over Xbox Live";
    homepage = "https://github.com/MCXboxBroadcast/Broadcaster";
    license = lib.licenses.gpl3Only;
    mainProgram = "mcxboxbroadcast";
  };
}

# Certificate for connecting to "GVSU Student" WiFi network
# Installs DigiCert Global Root CA to the system trust store
# GVSU's enterprise WiFi requires this root certificate for authentication
# Downloaded directly from GVSU's SecureW2 certificate distribution portal

# For the time being I am not going to explain how to write nix packages,
# As it is outside of the configuration scope

{
  lib,
  stdenv,
  fetchurl,
}:
stdenv.mkDerivation {
  pname = "gvsu-cert";
  version = "2024-12-19";

  src = fetchurl {
    url = "https://cloud.securew2.com/public/54120/GV-Student/certificates/digicertglobalrootca%20%5Bjdk%5D.cer";
    hash = "sha256-Of3PKK7/4I0DJR/Mr2RePF3hn6TruvyJtO3ipCIUi6s=";
  };

  dontUnpack = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/pki/trust/anchors
    cp $src $out/share/pki/trust/anchors/gvsu-student.crt

    runHook postInstall
  '';

  meta = with lib; {
    description = "GVSU Student WiFi Certificate";
    platforms = platforms.all;
    maintainers = with maintainers; [ Jamesx86-64 ];
  };
}

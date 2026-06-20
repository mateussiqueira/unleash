{ pkgs ? import <nixpkgs> {} }:

pkgs.stdenv.mkDerivation rec {
  pname = "unleash";
  version = "1.6.1";

  src = ./.;

  installPhase = ''
    mkdir -p $out/bin
    cp unleash $out/bin/
    chmod +x $out/bin/unleash
    cp -r lib $out/lib/
    cp -r examples $out/share/unleash/
  '';

  meta = with pkgs.lib; {
    description = "Single-script MDM bypass for macOS";
    homepage = "https://github.com/mateussiqueira/unleash";
    license = licenses.mit;
    platforms = platforms.darwin;
    maintainers = [ maintainers.mateussiqueira ];
  };
}

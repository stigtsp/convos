{ pkgs ? import <nixpkgs> {} }:

# The purpose of this shell.nix is to pull up a dev environment quickly. To use
# it, install the nix nix package manager run `nix-shell`
#
# Based on https://github.com/NixOS/nixpkgs/blob/master/pkgs/applications/networking/irc/convos/default.nix


with pkgs;
let _perl = perl.withPackages(p: with p; [
      CryptEksblowfish FileHomeDir FileReadBackwards
      IOSocketSSL IRCUtils JSONValidator LinkEmbedder ModuleInstall
      Mojolicious MojoliciousPluginOpenAPI MojoliciousPluginWebpack
      ParseIRC TextMarkdown TimePiece UnicodeUTF8
      CpanelJSONXS EV

      # For tests
      TestDeep TestMore
    ]);

in mkShell {
  buildInputs = [ _perl openssl ];
}

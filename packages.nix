# flake/packages.nix
{
  self,
  inputs,
  ...
}: {
  perSystem = {pkgs, ...}: {
    packages.hello = pkgs.hello;
  };
}

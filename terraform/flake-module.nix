{specialArgs ? {}, ...}: {
  imports = [
    (import ./null.nix {inherit specialArgs;})
  ];
}

{ hostUrlOpener }:
hostUrlOpener.overrideAttrs (old: {
  # xdg-open can exit before its browser. Keep the service alive for its children.
  buildCommand = old.buildCommand + ''
    substituteInPlace "$out/bin/nix-overlayfs-open-url" \
      --replace-fail '--collect' '--collect --property=ExitType=cgroup'
  '';
})

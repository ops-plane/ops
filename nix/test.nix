# Server with a local database and secrets from files, and a runner whose token the server registers at start. Run: nix build .#checks.x86_64-linux.nixos -L
self: {
  name = "ops";
  nodes.machine = {pkgs, ...}: {
    imports = [self.nixosModules.default];
    virtualisation.memorySize = 2048;
    # stand-ins for sops-nix secrets: root-owned files outside the store
    systemd.tmpfiles.rules = [
      "f+ /run/ops-secret-key 0400 root root - 0123456789abcdef0123456789abcdef"
      "f+ /run/ops-runner-token 0400 root root - fedcba9876543210fedcba9876543210"
    ];
    services.ops = {
      enable = true;
      publicUrl = "http://ops.test";
      secretKeyFile = "/run/ops-secret-key";
      runnerTokenFile = "/run/ops-runner-token"; # registered as runner "machine"; the runner's tokenFile defaults to it
      devUser = "admin@test";
      adminEmails = ["admin@test"];
      runner = {
        enable = true;
        terraformPackage = pkgs.opentofu; # terraform is unfree
      };
    };
  };
  testScript = ''
    machine.wait_for_unit("ops.service")
    machine.wait_until_succeeds("curl -sf http://127.0.0.1:8080/readyz")
    # the secret must not leak into the unit's environment
    machine.fail("systemctl show ops -p Environment | grep 0123456789abcdef")
    # no token step: the server registered the runner's token before it started
    machine.fail("systemctl show ops -p Environment | grep fedcba9876543210")
    machine.wait_until_succeeds("journalctl -u ops-runner | grep 'runner started'")
    # the job sandbox works under the unit's hardening (OPS_SANDBOX=namespaces: else the runner doesn't start)
    machine.succeed("journalctl -u ops-runner | grep 'job sandbox: namespaces'")
    machine.sleep(5)  # a rejected token would have stopped it by now
    machine.succeed("systemctl is-active ops-runner")
    # another runner's own token, for a host elsewhere
    machine.succeed("ops-admin runner-token -pool prd elsewhere | grep -q '^opsr_'")
    # it read the token as root and dropped to its user; jobs (same user) find no credentials directory
    machine.succeed("test $(stat -c %U /proc/$(systemctl show -p MainPID --value ops-runner)) = ops-runner")
    machine.fail("test -e /run/credentials/ops-runner.service")
    # a stop waits for the current job: its timeout (1h), OPS_JOB_GRACE to save state (10m) and 5 minutes to report
    machine.succeed("systemctl show -p TimeoutStopUSec --value ops-runner | grep -x '1h 15min'")
  '';
}

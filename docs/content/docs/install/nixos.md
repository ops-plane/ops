---
title: NixOS
weight: 3
---

Add this repository as a flake input and import its module. It creates a local PostgreSQL database by default, and passes secrets in from files (here from [sops-nix](https://github.com/Mic92/sops-nix)), so they never reach the Nix store:

```nix {filename="flake.nix"}
{
  inputs.ops.url = "github:ops-plane/ops";
  outputs = { nixpkgs, ops, ... }: {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [ ops.nixosModules.default ./configuration.nix ];
    };
  };
}
```

```nix {filename="configuration.nix"}
services.ops = {
  enable = true;
  publicUrl = "https://ops.example.com";
  secretKeyFile = config.sops.secrets.ops-secret-key.path;
  runnerTokenFile = config.sops.secrets.ops-runner-token.path;
  stateStore = "azblob://tfstate"; # default: files under /var/lib/ops
  oidc = {
    issuer = "https://login.example.com";
    clientId = "ops";
    clientSecretFile = config.sops.secrets.ops-oidc.path;
  };
  adminEmails = [ "you@example.com" ];
  # a runner on the same host; terraform is unfree (allowUnfree),
  # or set runner.terraformPackage = pkgs.opentofu
  runner.enable = true;
};
```

The server listens on `127.0.0.1:8080`: put a reverse proxy with TLS in front of it, for example nginx, at `publicUrl`.

## Options and secrets

[nix/module.nix](https://github.com/ops-plane/ops/blob/master/nix/module.nix) lists every option; the [option reference]({{< relref "/docs/config/reference" >}}) maps them to the env vars. Settings without an option (`METRICS_ADDR`, `SECRET_KEY_PREVIOUS`, cloud credentials) go in `environment`, secret ones in `secretFiles`. Secrets are `*File` options taking a path (e.g. `config.sops.secrets.<name>.path`), passed in through systemd credentials, so they never reach the Nix store. By default it creates a local Postgres database with peer auth.

`ops-admin` runs any subcommand with the server's settings: create registry tokens with `sudo ops-admin token <name>`, rotate the key with `sudo ops-admin rotate-key`. `runnerTokenFile` is the token of the runner on the server's host: the server registers it at start (as `runner.name`, default the hostname, in `runner.pool`), and the runner's `tokenFile` defaults to it. A runner on another host gets its own token, `sudo ops-admin runner-token [-pool p] <name>` (or Settings → Runners), as its `runner.tokenFile`. The runner runs in its own PID namespace, so jobs see no other processes of the host. It reads its secret files as root and then drops to its user, so module code (which runs as that user) can't read them. Test: `nix build .#checks.x86_64-linux.nixos` (NixOS VM, needs kvm).

## Next

[First steps]({{< relref "/docs/first-steps" >}}): connect your repositories, publish a module, create a template, add cloud credentials and deploy or import a first resource.

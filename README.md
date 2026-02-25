[![CI](https://github.com/James-1701/nix-infra/actions/workflows/ci.yaml/badge.svg)](https://github.com/James-1701/nix-infra/actions/workflows/ci.yaml)
![Flakes](https://img.shields.io/badge/Nix-Flake%20enabled-blue?logo=nixos&logoColor=white)
[![Built with Nix](https://img.shields.io/static/v1?logo=nixos&logoColor=white&label=&message=Built%20with%20Nix&color=5277C3)](https://builtwithnix.org)
![License](https://img.shields.io/badge/license-MIT-green)

# NixOS Fleet Configuration

A comprehensive Infrastructure as Code (IaC) repository managing a heterogeneous
fleet of NixOS systems, including development systems, cloud servers, virtual
machines and home infrastructure.

> This repository manages a heterogeneous fleet of NixOS systems
> **declaratively**, using **modern IaC practices** such as **reproducible
> builds**, **atomic upgrades**, **scalable configuration**, **secret
> management**, and **automated CI checks**.

## Table of Contents

- [Context & Motivation](#context--motivation)
- [Comparing IaC Solutions](#comparing-iac-solutions)
- [My Requirements](#my-requirements)
- [Infrastructure Highlights](#infrastructure-highlights)
- [Tech Stack](#tech-stack)
- [Hosted Services](#hosted-services)
- [Quick Start](#quick-start)
- [License](#license)

## Context & Motivation

Managing infrastructure across multiple machines often leads to configuration
drift and maintenance headaches, eventually the mental overhead of keeping track
of half a dozen systems becomes too much to handle. The solution to this problem
is to treat infrastructure as code, and to manage it in a declarative way,
ensuring that your infrastructure is reproducible, version-controlled, and
drift-free.

## Comparing IaC Solutions

There are several different approaches to IaC, each targeting different layers
of infrastructure:

- **Terraform** – Designed for provisioning cloud resources (VMs, networks,
  storage), but doesn’t configure what’s inside your servers.

- **Kubernetes** – Manages containerized applications, not the underlying OS or
  packages. Useful for app orchestration rather than system configuration.

- **Ansible / Puppet / Chef** – Focused on configuring servers after they exist.
  Ansible is the most widely used configuration management tool, it applies
  tasks to bring a system from its current state to the desired state.

- **Nix/NixOS** – Combines package management and full system configuration in a
  single declarative language. Supports reproducible builds, atomic upgrades,
  and rollbacks.

For my setup, I chose Nix because it allows me to define the entire system state
declaratively, making it easier to reproduce environments across multiple
machines, manage complex dependencies, and safely roll back changes if something
breaks.

Unlike tools like Ansible, which manage the chaos of existing systems by
applying changes on top of whatever state currently exists, Nix takes a purely
declarative approach that removes disorder at its source. With Nix, every system
is built from a single source of truth, so there’s no hidden state or drift.
What you define in code is exactly what gets deployed, with no exceptions.

## My Requirements

This infrastructure is designed to meet these core requirements:

- **Declarative** – Defines the desired system state in code, specifying exactly
  the environment of each system.
- **Reproducible** – Machines built are identical, deterministic, and fully
  version-controlled.
- **Scalable** – Makes it easy to add new hosts without copying and pasting
  configuration.
- **Secure** – Manages secrets safely and automatically detects leaks.

> This repository serves as the single source of truth for my entire digital
> infrastructure, leveraging the power of Nix Flakes and modern DevOps
> practices.

## Infrastructure Highlights

- **Trait-Based Architecture:** Utilizing
  [Nix Lineage](https://github.com/James-1701/nix-lineage) to define host roles
  and capabilities abstractly. Hosts declare *what* they are (e.g., "CI Runner",
  "Gaming PC"), and the configuration automatically derives the necessary
  services and packages.

- **Private Mesh Networking:** All hosts are connected via a private mesh VPN.
  Services are not exposed directly to the internet; instead, traffic is routed
  using a managed domain, providing HTTPS access via named subdomains (e.g.
  `git.example.com`) without exposing raw IPs or ports.

- **Secret Management:** Secrets are encrypted at rest using **SOPS** (Secrets
  OPerationS) with **age** encryption, seamlessly integrated via `sops-nix`.

- **Reproducible Development:** A fully self-contained development shell defined
  in `flake.nix` provides all necessary tools (`sops`, `age`, `nixos-anywhere`,
  `neovim`, etc.) ensuring that anyone (or any CI runner) interacting with the
  repo has the exact same toolset.

- **Automated Quality Assurance:** Rigorous checks are enforced both locally and
  in CI:

  - **Linting:** `deadnix` (unused code), `statix` (anti-patterns), `shellcheck`
    (script safety).
  - **Formatting:** `treefmt` ensures consistent code style across all files.
  - **Security:** `gitleaks` and `trufflehog` scan for accidental secret
    commits.
  - **Typos:** `typos` checker to catch spelling errors.

### Organization

- **`flake.nix`**: The entry point. Defines inputs, outputs, developer shells,
  and the host construction logic.
- **`hosts/`**: Declarative definitions for each machine in the fleet.
  - Examples: `dev-laptop-01.nix`, `prod-cloud-01.nix`.
- **`modules/`**: Reusable configuration blocks categorized by function.
  - **`nixos/`**: System-level modules (virtualization, desktop environments,
    security).
  - **`home/`**: User-level modules (applications, shell configuration).
- **`pkgs/`**: Custom package declarations for use within modules.
- **`lineage/`**: The trait database defining the hierarchy of roles (e.g., a
  "Git Server" implies "Nginx" which implies "SSH Access").
- **`secrets/`**: Encrypted secrets managed by SOPS.

## Tech Stack

This infrastructure is built with the following:

- **Nix / NixOS**: The core operating system and package manager.
- **Nix Flakes**: For reproducible project structure.
- **Remote builders**: Weaker machines can offload builds to stronger ones.
- **GitHub Actions**: CI/CD for automated testing and checks.
- **Pre-commit Hooks**: For enforcing code quality standards before code is
  committed.
- **SOPS & Age**: For secure, encrypted secret management.
- **Nix Lineage**: For trait resolution from hostfiles.
- **Impermanence**: Mounts `/` on `tmpfs`, so only explicitly persisted data
  survives across reboots.
- **Disko**: For declarative disk partitioning and management.
- **Lanzaboote**: For Secure Boot support.
- **Home Manager**: For managing user environments.

## Hosted Services

This infrastructure runs the following:

- **Private mesh networking** (Tailscale)
- **Secure remote access** (SSH)
- **Reverse proxy and TLS termination** (Nginx)
- **Monitoring and metrics across all systems** (Prometheus + Grafana)
- **Self-hosted Git service** (Forgejo)
- **File storage and collaboration platform** (Nextcloud)
- **Workflow automation** (n8n)
- **Game servers** (Minecraft)
- **Local AI / LLM workloads** (Ollama)

## Quick Start

### Prerequisites

- Nix with Flakes enabled.
- `direnv` (recommended) to automatically load the dev environment.

### Setup

1. Clone the repository:

   ```bash
   git clone https://github.com/James-1701/nix-infra
   cd nix-infra
   ```

1. Enter the development environment:

   ```bash
   # With direnv
   direnv allow
   # Or manually:
   nix develop
   ```

### Usage

1. Deploying a Host

   To deploy configuration to a remote host:

   ```bash
   ./scripts/install.sh <host-name> <ip>
   ```

1. Updating

   ```bash
   # With nh (recommended)
   nh os switch
   # With nixos-rebuild
   nixos-rebuild switch
   ```

1. Managing Secrets

   To edit secrets (requires access to the age key):

   ```bash
   sops secrets/secrets.yaml
   ```

## License

This project is licensed under the **MIT License**. See the [LICENSE](LICENSE)
file for details.

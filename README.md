# sakuya

GitOps repo for my single-node homelab Kubernetes cluster. Everything in the
cluster is declared here and applied by Flux; the node itself is configured by
Talos machine-config patches in `talos/`.

| | |
|---|---|
| **Node** | Talos Linux v1.14 on a Proxmox VM (4 vCPU, 12 GB RAM, 100 GB disk) |
| **GitOps** | Flux v2, reconciling from a self-hosted Forgejo |
| **Secrets** | SOPS + age: encrypted in git, decrypted by Flux in the cluster |
| **Networking** | MetalLB (L2), Traefik (Gateway API), NetBird mesh for remote access |
| **TLS** | cert-manager, Let's Encrypt wildcard via DNS-01 (Porkbun) |
| **Storage** | local-path-provisioner on a dedicated Talos user volume |
| **Database** | CloudNativePG, WAL archiving + daily base backups to Cloudflare R2 |
| **Monitoring** | vmagent, kube-state-metrics, node-exporter, blackbox-exporter, vmalert (to an external VictoriaMetrics + Alertmanager) |
| **Workloads** | Forgejo Actions runners (Docker-in-Docker), two CronJobs migrated from a desktop crontab |

## Architecture

```
   at home                                 away (NetBird mesh)
   router DNS -> 192.168.1.230             public DNS -> 100.81.132.122
          | MetalLB (L2/ARP)                       | Service externalIPs
          +--------------------+-------------------+
                               v
  +-------------------------- sakuya (Talos) ---------------------------+
  |  Traefik (Gateway API) -> HTTPRoutes -> apps                        |
  |  Flux                        CronJobs: chefcal, eink-cal            |
  |  CNPG pg-main (2 instances)  Forgejo runner "kappa" + dind          |
  |  vmagent, vmalert            cert-manager, MetalLB, local-path      |
  +---------------------------------------------------------------------+
       |              |                 |                   |
       | pulls git    | polls for jobs  | WAL + backups     | metrics, alerts
       v              v                 v                   v
    Forgejo        Forgejo           Cloudflare R2       VictoriaMetrics +
    (this repo)    Actions                               Alertmanager
```

Apart from ingress, every connection starts from inside the cluster: Flux
pulls from git, the runner polls Forgejo for jobs, metrics are pushed out.
Nothing is exposed to the public internet. Both DNS views resolve the same
names (`*.sakuya.kinoko.house`) to different addresses: the LAN router answers
with the MetalLB IP, public DNS with the node's NetBird mesh IP. One wildcard
certificate covers both paths.

## Reconciliation order

Flux applies four Kustomizations in a chain, each waiting for the previous one
to be healthy (`dependsOn` + `wait: true`), so custom resources never race the
controllers that define their CRDs:

| Kustomization | Path | Contents |
|---|---|---|
| `infra-crds` | upstream Gateway API release | Gateway API CRDs (`prune: false`) |
| `infra-controllers` | `infrastructure/controllers/` | HelmReleases: MetalLB, Traefik, cert-manager, CNPG, local-path, monitoring |
| `infra-configs` | `infrastructure/configs/` | IP pools, ClusterIssuers, the wildcard Certificate |
| `apps` | `apps/` | Workloads |

## Tested, not assumed

| Claim | How it was tested |
|---|---|
| The cluster is reproducible from git | Node wiped and rebuilt; `flux bootstrap` found nothing to change |
| Postgres survives losing its primary | Primary deleted during a write loop: one failed insert, replica promoted in ~1 s |
| Backups restore | Table dropped, cluster restored to a point 2 s before the drop from R2 |
| Alerting reaches a human | Metrics agent scaled to zero: alert fired after ~7 min, email received, resolved on recovery |
| CI jobs stay inside their pod's limits | CPU burn test in a runner job, before and after a cgroup fix |
| Certificates can't expire silently | Blackbox probes with expiry and probe-failure alerts |

## Rebuilding from scratch

1. Boot the Talos ISO (Image Factory schematic in `talos/schematic.yaml`).
2. `talos/gen.sh` (renders and validates the config from `talos/patches/`),
   then `talosctl apply-config --insecure` and `talosctl bootstrap`.
3. Create the two secrets that can't live in git: the age key
   (`flux-system/sops-age`) and the Flux deploy key.
4. `flux bootstrap git` against this repo. Everything else follows.

## Layout

| Path | What |
|---|---|
| `talos/` | Talos machine-config patches, schematic, encrypted cluster secrets (generated configs are gitignored) |
| `clusters/sakuya/` | Flux entrypoint: Flux itself and the Kustomization chain |
| `infrastructure/controllers/` | Cluster add-ons as HelmReleases |
| `infrastructure/configs/` | Custom resources that need those add-ons' CRDs |
| `apps/` | Workloads, one directory each |

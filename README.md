# sakuya

GitOps repo for my single-node homelab Kubernetes cluster.

- **OS:** Talos Linux (VM: 4 vCPU, 12 GB RAM, 100 GB disk)
- **GitOps:** Flux, reconciling from this repo on Forgejo (nitori)
- **Secrets:** SOPS + age
- **Platform:** cert-manager, external-dns (Porkbun), CloudNativePG
- **Workloads:** Forgejo Actions runners, eink-cal and chefcal CronJobs

## Layout

| Path | What |
|---|---|
| `talos/` | Talos machine-config patches (generated configs are gitignored) |
| `clusters/sakuya/` | Flux entrypoint for this cluster |
| `infrastructure/` | Cluster add-ons (controllers, then their config) |
| `apps/` | Workloads |
| `docs/blog-notes.md` | Running notes for the write-up |

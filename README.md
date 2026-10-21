# dagger-gha-probe

Small GitHub Actions jobs that check what Dagger can and cannot do on GitHub-hosted
runners. Each job asks one question and writes a PASS, FAIL or BASELINE line to the run
summary that says what it measured.

| Job | Question |
|---|---|
| `engine-boot` | Does the engine provision and run a container, and how long is a cold start? |
| `cache-in-job` | Does an identical second pipeline in the same job hit the cache? |
| `cache-volume` | Does a cache volume keep its contents across pipelines in one job? |
| `secrets` | Does Dagger keep a secret out of stdout and its progress log? |
| `services` | Can a pipeline reach a Dagger service container by hostname? |
| `cache-across-runs-default` | Does the cache survive into the next workflow run with no setup? |
| `cache-across-runs-persisted` | Does it survive if we archive the engine's state with `actions/cache`? |
| `windows` | Does Dagger work on `windows-latest` at all? |

The cross-run jobs need two runs: the first seeds the cache, the re-run measures it.

The Dagger version is pinned in `mise.toml`, which CI installs through `jdx/mise-action`.
To run a probe locally: `mise install`, then `ci/<probe>.sh`.

# Local CI

GitHub Actions is configured but requires billing to be resolved on the account.
Until then, run CI locally with one of these methods:

## Makefile

```bash
make ci
```

Runs ShellCheck, bash syntax check, and markdown lint in sequence.

## act (Docker-based)

Requires Docker Desktop running.

```bash
act -j shellcheck -W .github/workflows/ci.yml --container-architecture linux/amd64
act -j syntax -W .github/workflows/ci.yml --container-architecture linux/amd64
act -j markdown -W .github/workflows/ci.yml --container-architecture linux/amd64
```

Or all at once:

```bash
act --container-architecture linux/amd64
```

## CircleCI

A `.circleci/config.yml` is included. Connect the repo at https://circleci.com to
use it as a free CI alternative (public repos get 6000 free minutes/month).

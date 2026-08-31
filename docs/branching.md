# Branching and upstream sync

PlayTorrioMod is a fork of [`ayman708-UX/PlayTorrioV3`](https://github.com/ayman708-UX/PlayTorrioV3).
It diverges deliberately, still wants useful changes *from* upstream, and still
wants to contribute *to* upstream. Those are three different jobs, and only two
of them are branches.

## The shape

```
e5b001b  ← the last commit shared with upstream (the fork point)
│
├── main                    the fork's trunk; +71 commits and counting
├── pr/<topic>              one per upstream contribution; only that fix
└── port/<topic>            one per upstream change being pulled in
```

| Purpose | Mechanism | Lifetime |
|:--|:--|:--|
| The fork itself | `main` | permanent |
| Fork work | `fix/…`, `feat/…` off `main` | delete on merge |
| Releases | tags `v*` | not branches |
| **Contribute to upstream** | `pr/<topic>` off the **fork point**, one per PR | until merged upstream |
| **Pull from upstream** | the `upstream` remote + `port/<topic>` off `main` | until merged |

## Contributing to upstream — `pr/<topic>`

Branch from the last commit shared with upstream, **not** from `main`. A branch
off `main` would carry all of the fork's divergence into the pull request; a
branch off the shared point carries only the fix.

```bash
git checkout -b pr/my-fix e5b001b        # or a newer upstream commit
git cherry-pick <sha-from-main>          # bring just the fix across
git push -u origin pr/my-fix
```

Such a branch reads as "71 behind, 2 ahead" of `main`. That is correct and
expected — behind-ness is the whole point.

**One branch per contribution.** A pull request is tied to a branch, so a
single shared branch would force every unrelated fix into one un-mergeable PR.
`pr/release-tooling` and `pr/security-hardening` are separate for that reason.

Before opening the PR, rebase onto upstream's *current* tip rather than the old
fork point, so it applies to the tree they actually have:

```bash
git fetch upstream
git rebase upstream/main pr/my-fix
```

If GitHub will not let you open a pull request from this repository to
upstream, the two repositories are not in the same fork network — check whether
the repository page says "forked from ayman708-UX/PlayTorrioV3". If it does
not, make a real fork of upstream, add it as a remote, and push the `pr/`
branch there instead. The branch itself does not change.

## Pulling from upstream — the `upstream` remote

There is no branch for this. Add the remote once per clone:

```bash
git remote add upstream https://github.com/ayman708-UX/PlayTorrioV3.git
git fetch upstream
```

Because a shared ancestor exists, git can tell you exactly what is new:

```bash
git log --oneline main..upstream/main     # upstream commits the fork lacks
git diff main...upstream/main -- lib/     # what changed, scoped to a path
```

Take changes one at a time onto a topic branch:

```bash
git checkout -b port/their-feature main
git cherry-pick <sha-from-upstream>
```

**Do not `git merge upstream/main` into `main`.** With ~71 divergent commits —
including the navigation rework, the package rename and the CI redesign — a
wholesale merge produces conflicts across most of the tree and buries the
fork's own decisions. Cherry-pick what is wanted; leave the rest.

Upstream's `v1.0.8` (`cd10d6c`) is not in the fork's history yet, so it is the
natural place to start when reviewing what to pull.

## Hygiene

- Delete topic branches once merged. GitHub's auto-delete-on-merge handles most
  of this; check for leftovers with `git branch -r --merged origin/main`.
- Keep `pr/` and `port/` prefixes — they say which direction a branch faces,
  which is the thing that is otherwise easy to forget.
- `main` is the default branch; run `git remote set-head origin main` if a
  clone shows no `origin/HEAD`.

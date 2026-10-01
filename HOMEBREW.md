# Publishing LastFile on Homebrew (free, via your own tap)

Homebrew's *official* cask list no longer accepts unsigned apps, but your **own tap** still works.
The cask removes the quarantine flag after install, so the app opens with no warning.

## One-time setup
1. Create an **empty public repo** named exactly `homebrew-tap` on your GitHub account.
2. Create a fine-grained token (GitHub → Settings → Developer settings → Personal access tokens):
   access to the `homebrew-tap` repo only, permission **Contents: Read and write**.
3. In your `LastFile` repo: Settings → Secrets and variables → Actions → new secret
   `HOMEBREW_TAP_TOKEN` = that token.

## Every release
```
git tag v1.2 && git push --tags
```
The workflow builds the app, publishes the Release, and writes `Casks/lastfile.rb` into your tap
with the correct version and checksum.

## What users type
```
brew install --cask YOUR_USER/tap/lastfile
```
(Upgrade later with `brew upgrade --cask lastfile`.)

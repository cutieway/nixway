# This file is embedded in the update-mudfish command by Home Manager.
set -euo pipefail

usage() {
  echo "Usage: update-mudfish VERSION" >&2
  echo "Example: update-mudfish 6.5.4" >&2
}

if [ "$#" -ne 1 ]; then
  usage
  exit 2
fi

new_version="$1"
if [[ ! "$new_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Mudfish VERSION must look like 6.5.4." >&2
  exit 2
fi

repo="${NIXWAY_REPO:?NIXWAY_REPO was not set by the NixOS configuration}"
package_relative="packages/mudfish/default.nix"
package_file="$repo/$package_relative"

cd "$repo"

mapfile -t pinned_versions < <(sed -n 's/^  version = "\([^"]*\)";$/\1/p' "$package_file")
mapfile -t pinned_hashes < <(sed -n 's/^      hash = "\(sha256-[^"]*\)";$/\1/p' "$package_file")

if [ "${#pinned_versions[@]}" -ne 1 ] || [ "${#pinned_hashes[@]}" -ne 1 ]; then
  echo "Could not identify exactly one Mudfish version and source hash in $package_file." >&2
  exit 1
fi

current_version="${pinned_versions[0]}"
current_hash="${pinned_hashes[0]}"

if [ "$new_version" = "$current_version" ]; then
  echo "Mudfish $new_version is already pinned; nothing was changed."
  exit 0
fi

oldest_version="$(printf '%s\n%s\n' "$current_version" "$new_version" | sort --version-sort | head -n 1)"
if [ "$oldest_version" != "$current_version" ]; then
  echo "Refusing to replace Mudfish $current_version with older version $new_version." >&2
  exit 1
fi

if [ -n "$(git status --porcelain -- "$package_relative")" ]; then
  echo "$package_relative already has uncommitted changes; review or commit them first." >&2
  exit 1
fi

current_url="https://mudfish.net/releases/mudfish-$current_version-linux-x86_64.sh"
new_url="https://mudfish.net/releases/mudfish-$new_version-linux-x86_64.sh"
release_notes_url="https://docs.mudfish.net/en/docs/mudfish-cloud-vpn/release-notes/"
workdir="$(mktemp -d /tmp/nixway-mudfish-update.XXXXXX)"
report="$(mktemp "/tmp/mudfish-update-$current_version-to-$new_version.XXXXXX.txt")"
original_package="$workdir/default.nix"
package_changed=false

cleanup() {
  status=$?
  trap - EXIT

  if [ "$status" -ne 0 ] && [ "$package_changed" = true ]; then
    cp "$original_package" "$package_file"
    echo "The package pin was restored because an update check failed." >&2
  fi

  rm -rf -- "$workdir"
  exit "$status"
}
trap cleanup EXIT

echo "Fetching the pinned Mudfish artifact for comparison..."
current_json="$(nix store prefetch-file --json "$current_url")"
fetched_current_hash="$(jq -r .hash <<<"$current_json")"
current_installer="$(jq -r .storePath <<<"$current_json")"

if [ "$fetched_current_hash" != "$current_hash" ]; then
  echo "The current Mudfish download no longer matches its pinned hash." >&2
  echo "Expected: $current_hash" >&2
  echo "Received: $fetched_current_hash" >&2
  exit 1
fi

echo "Fetching Mudfish $new_version..."
new_json="$(nix store prefetch-file --json "$new_url")"
new_hash="$(jq -r .hash <<<"$new_json")"
new_installer="$(jq -r .storePath <<<"$new_json")"

mkdir "$workdir/current" "$workdir/new"
sh "$current_installer" --noexec --target "$workdir/current" >/dev/null
sh "$new_installer" --noexec --target "$workdir/new" >/dev/null

expected_files=(
  bin/mudfish
  bin/mudflow
  bin/mudrun-headless
  bin/pkg_linux_setup.sh
  "etc/htdocs-www-$new_version.tar"
  share/mudrun_logo.png
)

for expected_file in "${expected_files[@]}"; do
  if [ ! -f "$workdir/new/$expected_file" ]; then
    echo "Mudfish $new_version is missing expected file: $expected_file" >&2
    exit 1
  fi
done

if [ ! -x "$workdir/new/bin/mudrun-headless" ]; then
  echo "Mudfish $new_version has a non-executable bin/mudrun-headless." >&2
  exit 1
fi

elf_report() {
  tree="$1"

  while IFS= read -r -d '' candidate; do
    if readelf -h "$candidate" >/dev/null 2>&1; then
      relative="${candidate#"$tree/"}"
      echo "[$relative]"
      readelf -l "$candidate" | sed -n '/Requesting program interpreter/p' || true
      readelf -d "$candidate" | sed -n '/NEEDED\|RPATH\|RUNPATH/p' || true
    fi
  done < <(find "$tree/bin" "$tree/sbin" -type f -print0 2>/dev/null | sort -z)
}

path_report() {
  tree="$1"

  while IFS= read -r -d '' candidate; do
    if readelf -h "$candidate" >/dev/null 2>&1; then
      relative="${candidate#"$tree/"}"
      matches="$(
        strings "$candidate" |
          grep -Eo '/(opt/mudfish|usr/(s?bin)|sbin)/[^[:space:]\"]+' |
          sort -u || true
      )"
      if [ -n "$matches" ]; then
        echo "[$relative]"
        printf '%s\n' "$matches"
      fi
    fi
  done < <(find "$tree/bin" "$tree/sbin" -type f -print0 2>/dev/null | sort -z)
}

{
  echo "Mudfish staged update review"
  echo "Current version: $current_version"
  echo "Candidate version: $new_version"
  echo "Current hash: $current_hash"
  echo "Candidate hash: $new_hash"
  echo "Current artifact: $current_url"
  echo "Candidate artifact: $new_url"
  echo "Release notes: $release_notes_url"
  echo
  echo "=== File manifest changes (path and byte size) ==="
  diff -u \
    <(cd "$workdir/current" && find . -type f -printf '%P %s\n' | sort) \
    <(cd "$workdir/new" && find . -type f -printf '%P %s\n' | sort) || true
  echo
  echo "=== Vendor setup script changes (not executed by this package) ==="
  diff -u \
    "$workdir/current/bin/pkg_linux_setup.sh" \
    "$workdir/new/bin/pkg_linux_setup.sh" || true
  echo
  echo "=== ELF interpreter and dependency changes ==="
  diff -u <(elf_report "$workdir/current") <(elf_report "$workdir/new") || true
  echo
  echo "=== Embedded system path changes ==="
  diff -u <(path_report "$workdir/current") <(path_report "$workdir/new") || true
} >"$report"

cp "$package_file" "$original_package"
sed -i "0,/  version = \"$current_version\";/s//  version = \"$new_version\";/" "$package_file"
sed -i "0,/      hash = \"sha256-[^\"]*\";/s||      hash = \"$new_hash\";|" "$package_file"
package_changed=true

echo "Checking formatting and the complete NixOS configuration..."
git diff --check
nix flake check --accept-flake-config "path:$repo"
nix build --no-link --accept-flake-config "path:$repo#nixosConfigurations.uwu.config.system.build.toplevel"

echo
echo "Mudfish $new_version is staged and checked, but it is not installed or running."
echo "Review report: $report"
echo "Review package diff: git -C $repo diff -- $package_relative"
echo "If everything looks right, run: rebuild"

{ pkgs, ... }:

let
  extractWith7zip = pkgs.writeShellApplication {
    name = "dolphin-extract-7zip";
    runtimeInputs = [
      pkgs._7zz
      pkgs.coreutils
      pkgs.gnugrep
      pkgs.kdePackages.kdialog
      pkgs.unrar
    ];
    text = ''
      archive_stem() {
        name="$1"
        lower="''${name,,}"

        case "$lower" in
          *.tar.bz2 | *.tar.zst)
            printf '%s' "''${name:0:''${#name}-8}"
            ;;
          *.tar.gz | *.tar.xz | *.7z.001)
            printf '%s' "''${name:0:''${#name}-7}"
            ;;
          *.tbz2 | *.tzst | *.zipx)
            printf '%s' "''${name:0:''${#name}-5}"
            ;;
          *.tgz | *.tb2 | *.txz | *.rar | *.zip | *.tar | *.bz2)
            printf '%s' "''${name:0:''${#name}-4}"
            ;;
          *.gz | *.xz | *.7z)
            printf '%s' "''${name:0:''${#name}-3}"
            ;;
          *.zst)
            printf '%s' "''${name:0:''${#name}-4}"
            ;;
          *)
            printf '%s' "''${name%.*}"
            ;;
        esac
      }

      is_compressed_tar() {
        lower="''${1,,}"
        case "$lower" in
          *.tar.gz | *.tgz | *.tar.bz2 | *.tbz2 | *.tb2 | *.tar.xz | *.txz | *.tar.zst | *.tzst)
            return 0
            ;;
          *)
            return 1
            ;;
        esac
      }

      is_rar() {
        lower="''${1,,}"
        case "$lower" in
          *.rar | *.r[0-9][0-9])
            return 0
            ;;
          *)
            return 1
            ;;
        esac
      }

      extract_archive() {
        archive="$1"
        destination="$2"
        password="''${3-}"
        password_args=()

        if [ -n "$password" ]; then
          password_args+=("-p$password")
        fi

        if is_rar "$archive"; then
          if [ -n "$password" ]; then
            unrar x -idq -o+ "-p$password" "$archive" "$destination/"
          else
            unrar x -idq -o+ -p- "$archive" "$destination/"
          fi
        elif is_compressed_tar "$archive"; then
          7zz x -so -bd "''${password_args[@]}" -- "$archive" </dev/null |
            7zz x -si -ttar -y -bd "-o$destination" >/dev/null
        else
          7zz x -y -bd "-o$destination" "''${password_args[@]}" -- "$archive" </dev/null
        fi
      }

      if [ "$#" -eq 0 ]; then
        kdialog --error "No archive was selected."
        exit 1
      fi

      extracted=0
      failures=()

      for archive in "$@"; do
        if [ ! -f "$archive" ]; then
          failures+=("$(basename -- "$archive"): not a local file")
          continue
        fi

        directory="$(dirname -- "$archive")"
        name="$(basename -- "$archive")"
        stem="$(archive_stem "$name")"
        if [ -z "$stem" ]; then
          stem=extracted
        fi
        destination="$directory/$stem"

        if [ -e "$destination" ]; then
          failures+=("$name: $stem already exists")
          continue
        fi

        mkdir -- "$destination"
        extraction_status=0
        if output="$(extract_archive "$archive" "$destination" 2>&1)"; then
          extracted=$((extracted + 1))
          continue
        else
          extraction_status=$?
        fi

        if grep --ignore-case --quiet password <<<"$output"; then
          if password="$(kdialog --password "Password for $name")" && [ -n "$password" ]; then
            if output="$(extract_archive "$archive" "$destination" "$password" 2>&1)"; then
              extracted=$((extracted + 1))
              continue
            else
              extraction_status=$?
            fi
          fi
        fi

        rmdir -- "$destination" 2>/dev/null || true
        printf 'Archive extraction failed for %s:\n%s\n' "$archive" "$output" >&2
        diagnostic="$(
          grep --ignore-case --extended-regexp \
            'unsupported|error|failed|cannot|corrupt|password|checksum|unexpected end' \
            <<<"$output" |
            tail -n 3 || true
        )"
        if [ -z "$diagnostic" ]; then
          diagnostic="extraction failed with status $extraction_status"
        fi
        failures+=("$name:\n$diagnostic")
      done

      if [ "''${#failures[@]}" -ne 0 ]; then
        failure_text="$(printf '%s\n' "''${failures[@]}")"
        kdialog --error "Some archives were not extracted:\n\n$failure_text\n\nExisting destination folders are never overwritten."
        exit 1
      fi

      if [ "$extracted" -eq 1 ]; then
        kdialog --passivepopup "Archive extracted" 4
      else
        kdialog --passivepopup "$extracted archives extracted" 4
      fi
    '';
  };
in
{
  xdg.dataFile."kio/servicemenus/nixway-extract-7zip.desktop" = {
    executable = true;
    text = ''
      [Desktop Entry]
      Type=Service
      MimeType=application/x-7z-compressed;application/zip;application/vnd.rar;application/vnd.comicbook-rar;application/x-tar;application/gzip;application/x-bzip2;application/x-xz;application/zstd;application/x-compressed-tar;application/x-bzip2-compressed-tar;application/x-xz-compressed-tar;application/x-zstd-compressed-tar;
      Actions=extractWith7zip;
      X-KDE-Protocols=file
      X-KDE-MinNumberOfUrls=1
      X-KDE-Priority=TopLevel

      [Desktop Action extractWith7zip]
      Name=Extract Here
      Icon=archive-extract
      Exec=${extractWith7zip}/bin/dolphin-extract-7zip %F
    '';
  };
}

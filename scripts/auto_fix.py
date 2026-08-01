#!/usr/bin/env python3
"""
NovaOS Auto-Fix: analyzes failed GitHub Actions build logs and applies
patches to the repo to fix common failure modes.

Usage:
    python3 auto_fix.py \
        --logs-dir logs \
        --build-logs-dir build-logs \
        --repo-root . \
        --commit-sha abc123 \
        --attempt 1 \
        --output-json fix-result.json

Strategy:
    1. Read combined logs from the failed run.
    2. Run a series of pattern-based "fixers" (RULES) against the log.
    3. If a rule matches, apply the corresponding patch to repo files.
    4. Optionally consult an LLM (ZAI_API_KEY env var) for unhandled errors.
    5. Write a JSON summary: {applied: bool, summary: str, patches: [...]}.

The fixers are deliberately conservative: they only edit files that are
safe to modify automatically (package lists, theme configs, scripts).
They never edit workflow files, secrets, or this script itself.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import time
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Callable

# Optional: requests for LLM call
try:
    import requests as _requests  # type: ignore
except ImportError:
    _requests = None


# =============================================================================
# Fixer framework
# =============================================================================

@dataclass
class FixResult:
    applied: bool = False
    summary: str = "no fix applied"
    patches: list[dict[str, Any]] = field(default_factory=list)
    rules_matched: list[str] = field(default_factory=list)


@dataclass
class Fixer:
    """A named, deterministic fix rule."""
    name: str
    description: str
    # Pattern (regex) searched against the combined log
    pattern: re.Pattern[str]
    # Function(log_match, repo_root) -> list[edited files]
    apply: Callable[[re.Match[str], Path], list[str]]


# =============================================================================
# Helpers
# =============================================================================

def read_file_safe(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8", errors="replace")
    except Exception:
        return ""


def write_file_safe(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")


def collect_logs(logs_dir: Path, build_logs_dir: Path | None) -> str:
    """Read every .txt / .log file under logs_dir and concatenate."""
    chunks: list[str] = []
    for d in [logs_dir, build_logs_dir]:
        if not d or not d.exists():
            continue
        for p in d.rglob("*"):
            if p.is_file() and p.suffix in (".txt", ".log"):
                try:
                    chunks.append(f"=== {p.name} ===\n" + p.read_text(encoding="utf-8", errors="replace"))
                except Exception:
                    continue
    return "\n".join(chunks)


# =============================================================================
# Fixers
# =============================================================================

def fix_missing_package(match: re.Match[str], root: Path) -> list[str]:
    """
    Archiso failure: 'error: target not found: <pkgname>'
    Fix: comment out the offending package in packages.x86_64.
    """
    pkg = match.group("pkg").strip()
    pkgfile = root / "packages.x86_64"
    if not pkgfile.exists():
        return []
    text = pkgfile.read_text(encoding="utf-8", errors="replace")
    new_lines = []
    edited = False
    for line in text.splitlines():
        # Skip comments and empty lines
        stripped = line.strip()
        if stripped and not stripped.startswith("#"):
            # Match exact package name (strip version constraints)
            line_pkg = re.split(r"[<>=\s]", stripped, 1)[0]
            if line_pkg == pkg:
                new_lines.append(f"# REMOVED by auto-fix: {line}  # package not found in repo")
                edited = True
                continue
        new_lines.append(line)
    if edited:
        write_file_safe(pkgfile, "\n".join(new_lines) + "\n")
        return [str(pkgfile)]
    return []


def fix_pacman_keyring(match: re.Match[str], root: Path) -> list[str]:
    """
    Keyring/signature errors -> ensure customize_airootfs.sh refreshes keyring.
    Only triggers on actual pacman signature errors, not just the word "keyring".
    """
    f = root / "airootfs/root/customize_airootfs.sh"
    if not f.exists():
        return []
    text = f.read_text(encoding="utf-8", errors="replace")
    # Only inject if the script doesn't already have a keyring refresh
    if "pacman-key --init" in text and "pacman-key --populate archlinux" in text:
        return []  # already there
    # Insert keyring refresh right after the first echo
    anchor = "echo \">>> Generating locales...\""
    inject = (
        'echo ">>> Refreshing archlinux-keyring (auto-fix)..."\n'
        "pacman -Sy --noconfirm archlinux-keyring || true\n"
        "pacman-key --init || true\n"
        "pacman-key --populate archlinux || true\n"
    )
    if anchor in text and inject.strip() not in text:
        new_text = text.replace(anchor, inject + anchor, 1)
        write_file_safe(f, new_text)
        return [str(f)]
    return []


def fix_archiso_missing_package(match: re.Match[str], root: Path) -> list[str]:
    """
    archiso: "Validating '<bootmode>': The '<pkg>' package is missing from
    the package list!" -> add the missing package to packages.x86_64.
    """
    pkg = match.group("pkg").strip()
    pfile = root / "packages.x86_64"
    if not pfile.exists():
        return []
    text = pfile.read_text(encoding="utf-8", errors="replace")
    # Check if already present (even commented out -> uncomment)
    for line in text.splitlines():
        s = line.strip()
        if s and not s.startswith("#"):
            if re.split(r"[<>=\s]", s, 1)[0] == pkg:
                return []  # already there
    # Add under the "## ---------- Bootloaders ----------" section if present,
    # else just append at the top.
    if "## ---------- Bootloaders ----------" in text:
        new_text = text.replace(
            "## ---------- Bootloaders ----------\n",
            f"## ---------- Bootloaders ----------\n{pkg}\n",
            1,
        )
    else:
        new_text = f"{pkg}\n" + text
    if new_text != text:
        write_file_safe(pfile, new_text)
        return [str(pfile)]
    return []


def fix_archiso_deprecated_bootmode(match: re.Match[str], root: Path) -> list[str]:
    """
    archiso: "The '<old>' boot mode is deprecated. Use '<new>' instead." ->
    rewrite profiledef.sh bootmodes to the new names.
    """
    pdef = root / "profiledef.sh"
    if not pdef.exists():
        return []
    text = pdef.read_text(encoding="utf-8", errors="replace")

    # Map deprecated names to their replacements
    replacements = {
        "bios.syslinux.mbr":            "bios.syslinux",
        "bios.syslinux.eltorito":       "bios.syslinux",
        "uefi-x64.systemd-boot.esp":    "uefi.systemd-boot",
        "uefi-x64.systemd-boot.eltorito": "uefi.systemd-boot",
    }
    new_text = text
    for old, new in replacements.items():
        new_text = new_text.replace(f'"{old}"', f'"{new}"')
        new_text = re.sub(rf'\b{re.escape(old)}\b', new, new_text)

    # Deduplicate (if both .mbr and .eltorito were present, we now have duplicates)
    bm_match = re.search(r'^export bootmodes=\(([^)]+)\)', new_text, re.MULTILINE)
    if bm_match:
        items = re.findall(r'"([^"]+)"', bm_match.group(1))
        # Preserve order, dedupe
        seen = set()
        deduped = []
        for it in items:
            if it not in seen:
                seen.add(it)
                deduped.append(it)
        new_list = " ".join(f'"{x}"' for x in deduped)
        new_text = re.sub(
            r'^export bootmodes=\([^)]+\)',
            f'export bootmodes=({new_list})',
            new_text,
            count=1,
            flags=re.MULTILINE,
        )

    if new_text != text:
        write_file_safe(pdef, new_text)
        return [str(pdef)]
    return []


def fix_community_repo_404(match: re.Match[str], root: Path) -> list[str]:
    """
    Arch Linux merged [community] into [extra] in 2023. If a mirror
    returns 404 for 'community.db', remove the [community] section from
    both pacman.conf files.
    """
    edited = []
    for pconf_path in [root / "pacman.conf", root / "airootfs/etc/pacman.conf"]:
        if not pconf_path.exists():
            continue
        text = pconf_path.read_text(encoding="utf-8", errors="replace")
        # Remove the [community] section (header + Include line, plus any
        # blank lines around it)
        new_text = re.sub(
            r"\n\[community\]\nInclude\s*=\s*/etc/pacman\.d/mirrorlist\n",
            "\n",
            text,
        )
        # Also remove any "community" mentions in repo lists
        if new_text != text:
            write_file_safe(pconf_path, new_text)
            edited.append(str(pconf_path))
    return edited


def fix_disk_space(match: re.Match[str], root: Path) -> list[str]:
    """
    'No space left on device' -> trim package list aggressively.
    Drop optional heavy packages (libreoffice-fresh, kdenlive, etc.).
    Only triggers on the EXACT error string, not just the words "disk space".
    """
    pfile = root / "packages.x86_64"
    if not pfile.exists():
        return []
    text = pfile.read_text(encoding="utf-8", errors="replace")
    # Aggressive trim: comment out known heavy optional packages
    heavy = [
        "libreoffice-fresh", "libreoffice-fresh-en-gb", "libreoffice-fresh-ar",
        "calibre", "kdenlive", "obs-studio", "handbrake", "audacity",
        "qemu", "qemu-desktop", "libvirt", "virt-manager", "virt-viewer",
        "docker", "docker-buildx", "docker-compose", "podman", "buildah",
        "jdk-openjdk", "maven", "gradle", "rustup", "go", "nodejs", "npm",
        "yarn", "pnpm", "pyenv", "thunderbird", "thunderbird-i18n-en-us",
        "thunderbird-i18n-ar", "chromium", "falkon", "filezilla",
        "transmission-qt", "qbittorrent", "calibre",
    ]
    new_lines = []
    edited = False
    for line in text.splitlines():
        stripped = line.strip()
        if stripped and not stripped.startswith("#"):
            line_pkg = re.split(r"[<>=\s]", stripped, 1)[0]
            if line_pkg in heavy:
                new_lines.append(f"# TRIMMED by auto-fix (disk space): {line}")
                edited = True
                continue
        new_lines.append(line)
    if edited:
        write_file_safe(pfile, "\n".join(new_lines) + "\n")
        return [str(pfile)]
    return []


def fix_qml_import_error(match: re.Match[str], root: Path) -> list[str]:
    """
    QML 'module "QtQuick.xxx" is not installed' errors in SDDM theme ->
    downgrade the import to a version that ships with the installed Qt.
    """
    module = match.group("module")
    qml_files = list((root / "airootfs/usr/share/sddm/themes").rglob("*.qml")) + \
                list((root / "airootfs/usr/share/plasma").rglob("*.qml")) + \
                list((root / "airootfs/usr/share/kwin").rglob("*.qml")) + \
                list((root / "airootfs/usr/share/wallpapers").rglob("*.qml"))
    edited = []
    for qf in qml_files:
        text = qf.read_text(encoding="utf-8", errors="replace")
        # If module is imported with a newer version, downgrade to 2.15
        new_text = re.sub(
            rf"import\s+{re.escape(module)}\s+\d+\.\d+",
            f"import {module} 2.15",
            text,
        )
        if new_text != text:
            write_file_safe(qf, new_text)
            edited.append(str(qf))
    return edited


def fix_pacman_conf_repo(match: re.Match[str], root: Path) -> list[str]:
    """
    'error: failed retrieving file [novaos] db' -> the local novaos repo
    isn't being created by CI. Disable it by commenting out.
    """
    pconf = root / "pacman.conf"
    if not pconf.exists():
        return []
    text = pconf.read_text(encoding="utf-8", errors="replace")
    if re.search(r"^\[novaos\]\s*$", text, re.MULTILINE):
        new_text = re.sub(
            r"^(\[novaos\]\n(?:SigLevel|Server).*)$",
            r"# Disabled by auto-fix (repo not built yet)\n# \1",
            text,
            flags=re.MULTILINE,
        ).replace("SigLevel = Optional TrustAll\nServer = file:///tmp/novaos-repo/x86_64",
                  "# SigLevel = Optional TrustAll\n# Server = file:///tmp/novaos-repo/x86_64")
        if new_text != text:
            write_file_safe(pconf, new_text)
            return [str(pconf)]
    return []


def fix_docker_pull(match: re.Match[str], root: Path) -> list[str]:
    """
    Docker image pull failure -> retry the pull with --platform and a fallback.
    We patch the workflow's docker run line to add --pull=always and a retry.
    """
    # NOTE: We avoid editing workflow files because that could create infinite
    # loops. Instead, log a clear actionable message for the human / next pass.
    return []  # no-op; the LLM path will handle complex workflow fixes


def fix_apt_package(match: re.Match[str], root: Path) -> list[str]:
    """
    'E: Unable to locate package <pkg>' on Ubuntu runner ->
    we can't easily fix the workflow YAML, but we can log it.
    """
    return []


# =============================================================================
# Rule registry (order matters: most specific first)
# =============================================================================

RULES: list[Fixer] = [
    # ---------- archiso-specific errors (most specific, check first) ----------
    Fixer(
        name="archiso-missing-boot-package",
        description="archiso: a required bootloader package is missing from packages.x86_64 -> add it",
        pattern=re.compile(
            r"Validating[^:]*:\s*The\s+'(?P<pkg>[\w\-\.+]+)'\s+package\s+is\s+missing\s+from\s+the\s+package\s+list",
            re.IGNORECASE,
        ),
        apply=fix_archiso_missing_package,
    ),
    Fixer(
        name="archiso-deprecated-bootmode",
        description="archiso: deprecated boot mode name -> rewrite profiledef.sh to use the new name",
        pattern=re.compile(
            r"The\s+'(?P<old>bios\.syslinux\.(?:mbr|eltorito)|uefi-x64\.systemd-boot\.(?:esp|eltorito))'\s+boot\s+mode\s+is\s+deprecated",
            re.IGNORECASE,
        ),
        apply=fix_archiso_deprecated_bootmode,
    ),
    Fixer(
        name="community-repo-404",
        description="pacman: community.db 404 (Arch merged [community] into [extra] in 2023) -> remove [community] from pacman.conf",
        pattern=re.compile(
            r"failed retrieving file.*community\.db.*returned error:\s*404",
            re.IGNORECASE,
        ),
        apply=fix_community_repo_404,
    ),
    Fixer(
        name="missing-package",
        description="pacman: target package not found in repos -> comment it out of packages.x86_64",
        pattern=re.compile(r"error:\s*target not found:\s*(?P<pkg>[\w\-\.@+]+)", re.IGNORECASE),
        apply=fix_missing_package,
    ),
    # ---------- signature / keyring errors (specific phrases only) ----------
    Fixer(
        name="pacman-keyring",
        description="pacman: signature/keyring error -> inject keyring refresh in customize_airootfs.sh",
        pattern=re.compile(
            r"(invalid or corrupted package \(PGP signature\)|"
            r"failed to commit transaction.*invalid or corrupted|"
            r"error: key \"[A-F0-9]+\" could not be imported|"
            r"unknown trust|"
            r"the signature could not be verified)",
            re.IGNORECASE,
        ),
        apply=fix_pacman_keyring,
    ),
    Fixer(
        name="qml-import",
        description="QML module not installed -> downgrade import version to 2.15",
        pattern=re.compile(r'module\s+"(?P<module>QtQuick[^"]*)"\s+is not installed', re.IGNORECASE),
        apply=fix_qml_import_error,
    ),
    Fixer(
        name="novaos-repo-missing",
        description="Local [novaos] repo not reachable -> disable it in pacman.conf",
        pattern=re.compile(r"failed retrieving file.*novaos.*db", re.IGNORECASE),
        apply=fix_pacman_conf_repo,
    ),
    Fixer(
        name="disk-space",
        description="Out of disk space -> trim heavy optional packages",
        pattern=re.compile(r"No space left on device", re.IGNORECASE),
        apply=fix_disk_space,
    ),
    Fixer(
        name="docker-pull",
        description="Docker pull failure -> no-op (workflow edit needs human review)",
        pattern=re.compile(r"manifest.*not found|failed to resolve.*manifest", re.IGNORECASE),
        apply=fix_docker_pull,
    ),
    Fixer(
        name="apt-package-missing",
        description="Apt package missing on runner -> no-op (workflow edit needs human review)",
        pattern=re.compile(r"E:\s*Unable to locate package\s+(?P<pkg>[\w\-]+)", re.IGNORECASE),
        apply=fix_apt_package,
    ),
]


# =============================================================================
# Optional LLM fallback (uses ZAI API if ZAI_API_KEY is set)
# =============================================================================

def llm_suggest_fix(logs: str, repo_root: Path) -> dict[str, Any] | None:
    """Ask the ZAI LLM to suggest a fix for an unhandled error."""
    if not _requests:
        return None
    api_key = os.environ.get("ZAI_API_KEY")
    if not api_key:
        return None

    # Trim logs to a manageable size
    snippet = logs[-8000:] if len(logs) > 8000 else logs

    # Build a concise inventory of the repo so the LLM has context
    inventory = subprocess.run(
        ["find", str(repo_root), "-maxdepth", "3", "-type", "f",
         "-not", "-path", "*/.git/*", "-not", "-path", "*/work/*"],
        capture_output=True, text=True, timeout=10,
    ).stdout[:4000]

    prompt = (
        "You are NovaOS Auto-Fix, an expert DevOps engineer. "
        "Below is the tail of a failed GitHub Actions log building an Arch Linux ISO via archiso. "
        "Suggest ONE concrete file edit that would fix the failure. "
        "Reply with a JSON object: "
        '{"file": "<relative path>", "find": "<exact text to find>", "replace": "<replacement text>", "reason": "<short>"}'
        "\n\nRepo inventory:\n" + inventory +
        "\n\nLog excerpt:\n" + snippet
    )

    try:
        # ZAI uses OpenAI-compatible endpoint
        resp = _requests.post(
            "https://api.z.ai/api/paas/v4/chat/completions",
            headers={
                "Authorization": f"Bearer {api_key}",
                "Content-Type": "application/json",
            },
            json={
                "model": "glm-4.6",
                "messages": [
                    {"role": "system", "content": "You are a precise DevOps assistant. Output only valid JSON."},
                    {"role": "user", "content": prompt},
                ],
                "temperature": 0.2,
                "max_tokens": 800,
            },
            timeout=30,
        )
        resp.raise_for_status()
        content = resp.json()["choices"][0]["message"]["content"]
        # Extract JSON from possibly-markdown-wrapped response
        m = re.search(r"\{[\s\S]*\}", content)
        if m:
            return json.loads(m.group(0))
    except Exception as e:
        print(f"[auto-fix] LLM call failed: {e}", file=sys.stderr)
    return None


def apply_llm_fix(suggestion: dict[str, Any], repo_root: Path) -> list[str]:
    """Apply an LLM-suggested find/replace edit if it looks safe."""
    file_rel = suggestion.get("file", "")
    find = suggestion.get("find", "")
    replace = suggestion.get("replace", "")
    reason = suggestion.get("reason", "")

    if not file_rel or not find:
        return []

    # SAFETY: never edit workflow files, secrets, or this script
    forbidden_prefixes = (
        ".github/workflows",
        "scripts/auto_fix.py",
        ".env", ".git/", "secrets",
    )
    if file_rel.startswith(forbidden_prefixes):
        print(f"[auto-fix] LLM suggestion touched forbidden path: {file_rel}")
        return []

    target = (repo_root / file_rel).resolve()
    # Ensure the target is inside repo_root
    try:
        target.relative_to(repo_root.resolve())
    except ValueError:
        print(f"[auto-fix] LLM suggestion outside repo: {target}")
        return []

    if not target.is_file():
        print(f"[auto-fix] LLM suggested file does not exist: {target}")
        return []

    text = target.read_text(encoding="utf-8", errors="replace")
    if find not in text:
        print(f"[auto-fix] LLM 'find' string not present in {target}")
        return []

    new_text = text.replace(find, replace, 1)
    if new_text == text:
        return []

    target.write_text(new_text, encoding="utf-8")
    print(f"[auto-fix] LLM fix applied to {target}: {reason}")
    return [str(target)]


# =============================================================================
# Main
# =============================================================================

def main() -> int:
    ap = argparse.ArgumentParser(description="NovaOS Auto-Fix")
    ap.add_argument("--logs-dir", type=Path, required=True)
    ap.add_argument("--build-logs-dir", type=Path, default=None)
    ap.add_argument("--repo-root", type=Path, required=True)
    ap.add_argument("--commit-sha", default="")
    ap.add_argument("--attempt", type=int, default=0)
    ap.add_argument("--output-json", type=Path, required=True)
    args = ap.parse_args()

    result = FixResult()

    # 1. Collect logs
    logs = collect_logs(args.logs_dir, args.build_logs_dir)
    if not logs:
        result.summary = "no logs found to analyze"
        args.output_json.write_text(json.dumps(result.__dict__, indent=2))
        return 0

    print(f"[auto-fix] Analyzing {len(logs)} chars of logs (attempt {args.attempt + 1}/5)")

    # 2. Run rule-based fixers
    for fixer in RULES:
        m = fixer.pattern.search(logs)
        if m:
            print(f"[auto-fix] Rule matched: {fixer.name} - {fixer.description}")
            result.rules_matched.append(fixer.name)
            try:
                edited = fixer.apply(m, args.repo_root)
                if edited:
                    result.patches.append({"rule": fixer.name, "files": edited})
                    result.applied = True
                    result.summary = f"{fixer.name}: {fixer.description}"
                    break  # Apply ONE fix per run (re-build will catch the rest)
            except Exception as e:
                print(f"[auto-fix] ERROR applying {fixer.name}: {e}", file=sys.stderr)

    # 3. If no rule matched, try LLM (if available)
    if not result.applied:
        suggestion = llm_suggest_fix(logs, args.repo_root)
        if suggestion:
            edited = apply_llm_fix(suggestion, args.repo_root)
            if edited:
                result.patches.append({"rule": "llm-suggestion", "files": edited,
                                       "reason": suggestion.get("reason", "")})
                result.applied = True
                result.summary = f"llm-suggestion: {suggestion.get('reason', 'applied LLM suggestion')}"
        else:
            result.summary = "no rule matched and LLM unavailable or no suggestion"

    # 4. Write result JSON
    args.output_json.parent.mkdir(parents=True, exist_ok=True)
    args.output_json.write_text(json.dumps(result.__dict__, indent=2))
    print(f"[auto-fix] Result: applied={result.applied}  summary={result.summary}")
    return 0 if result.applied else 1


if __name__ == "__main__":
    sys.exit(main())

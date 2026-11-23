#!/usr/bin/env python3
"""Build the GitHub Pages site: homepage (site/) + MMRL repository index.

MMRL fetches <base>/json/modules.json (base = the URL users add, with a trailing slash).
Versions come from the GitHub releases that carry a docker-magisk-*.zip; each version's
changelog is its section of CHANGELOG.md.

Usage: [GH_TOKEN=...] [REPO=owner/name] scripts/build-site.py <output dir>
"""
import json
import os
import re
import shutil
import sys
import urllib.request
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
REPO = os.environ.get("REPO") or os.environ.get("GITHUB_REPOSITORY") or "fortmea/docker-rosemary"
OWNER, NAME = REPO.split("/")
BASE = f"https://{OWNER.lower()}.github.io/{NAME}/"
GITHUB = f"https://github.com/{REPO}"
ZIP_RE = re.compile(r"^docker-magisk-.+\.zip$")


def api(path):
    """GET every page of a GitHub REST list endpoint."""
    items, url = [], f"https://api.github.com/{path}?per_page=100"
    headers = {"Accept": "application/vnd.github+json", "User-Agent": "build-site"}
    if os.environ.get("GH_TOKEN"):
        headers["Authorization"] = f"Bearer {os.environ['GH_TOKEN']}"
    while url:
        with urllib.request.urlopen(urllib.request.Request(url, headers=headers)) as r:
            items += json.load(r)
            nxt = re.search(r'<([^>]+)>;\s*rel="next"', r.headers.get("Link", ""))
            url = nxt.group(1) if nxt else None
    return items


def version_code(version):
    # Same formula as scripts/build-module.sh (module.prop versionCode).
    docker, rev = version.rsplit("-", 1)
    major, minor, patch = (int(x) for x in docker.split("."))
    return major * 1000000 + minor * 10000 + patch * 100 + int(rev)


def changelog_section(text, version):
    m = re.search(rf"^## \[{re.escape(version)}\][^\n]*\n(.*?)(?=^## \[|^\[[^\]]+\]: |\Z)",
                  text, re.M | re.S)
    return m.group(1).strip() if m else ""


def epoch(iso):
    return datetime.fromisoformat(iso.replace("Z", "+00:00")).timestamp()


def main(out):
    out = Path(out)
    shutil.rmtree(out, ignore_errors=True)
    shutil.copytree(ROOT / "site", out)
    (out / ".nojekyll").touch()
    (out / "json").mkdir()
    (out / "changelog").mkdir()
    changelog = (ROOT / "CHANGELOG.md").read_text()

    versions = []
    for rel in api(f"repos/{REPO}/releases"):
        if rel["draft"] or rel["prerelease"]:
            continue
        asset = next((a for a in rel["assets"] if ZIP_RE.match(a["name"])), None)
        if not asset:
            continue
        version = rel["tag_name"].removeprefix("v")
        notes = changelog_section(changelog, version)
        log_url = ""
        if notes:
            (out / "changelog" / f"{version}.md").write_text(f"## {version}\n\n{notes}\n")
            log_url = f"{BASE}changelog/{version}.md"
        versions.append({
            "timestamp": epoch(rel["published_at"]),
            "version": version,
            "versionCode": version_code(version),
            "zipUrl": asset["browser_download_url"],
            "changelog": log_url,
            "size": asset["size"],
        })
    if not versions:
        sys.exit("no release with a docker-magisk-*.zip asset found")
    versions.sort(key=lambda v: v["versionCode"], reverse=True)  # newest first
    latest = versions[0]

    module = {
        "id": "docker",  # must match module.prop
        "name": "Docker",
        "version": latest["version"],
        "versionCode": latest["versionCode"],
        "author": OWNER,
        "description": "Official Docker Engine + Compose running natively on rooted Android "
                       "(tested on Xiaomi rosemary / LineageOS). Needs a kernel with the "
                       "options in kernel/docker.config: see the homepage.",
        "added": versions[-1]["timestamp"],
        "timestamp": latest["timestamp"],
        "size": latest["size"],
        "categories": ["Tools", "Containers"],
        "homepage": BASE,
        "support": f"{GITHUB}/issues",
        "license": "MIT",
        "readme": f"https://raw.githubusercontent.com/{REPO}/main/README.md",
        "arch": ["arm64-v8a"],
        "features": {"service": True},
        "track": {"type": "ONLINE_JSON", "added": versions[-1]["timestamp"],
                  "source": GITHUB, "antifeatures": []},
        "versions": versions,
    }
    index = {
        "name": "docker-rosemary",
        "website": BASE,
        "support": f"{GITHUB}/issues",
        "submission": None,
        "description": "Docker for rooted Android (Xiaomi rosemary).",
        "metadata": {"version": 1, "timestamp": latest["timestamp"]},
        "modules": [module],
    }
    (out / "json" / "modules.json").write_text(json.dumps(index, indent=2) + "\n")
    print(f"{out}: {len(versions)} versions, latest {latest['version']}")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    main(sys.argv[1])

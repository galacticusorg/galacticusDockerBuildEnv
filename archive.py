#!/usr/bin/env python3
import json
import os
import re
import sys
import urllib.request
import urllib.error

# Retrieve and archive copies of all dependencies for Galacticus' build environment.
# Andrew Benson (26-February-2024)

if len(sys.argv) != 4:
    raise SystemExit("Usage: archive.py <dockerFile> <archivePath> <slackToken>")

docker_file_name = sys.argv[1]
archive_path     = sys.argv[2]
slack_token      = sys.argv[3]

report_text = ""
gcc_version = None

with open(docker_file_name) as f:
    for line in f:
        m = re.search(r'^ENV\s+GCC_VERSION\s*=\s*(\S*)', line)
        if m:
            gcc_version = m.group(1)
        m = re.search(r'^(RUN\s)??\s*wget\s+(\S+)', line)
        if not m:
            continue
        source = m.group(2)
        if gcc_version:
            source = source.replace('$GCC_VERSION', gcc_version)
        m2 = re.search(r'^(?:http|https|ftp)://(.+)/([^/]+)$', source)
        if not m2:
            continue
        path      = m2.group(1)
        file_name = m2.group(2)
        dest_dir  = os.path.join(archive_path, path)
        dest_file = os.path.join(dest_dir, file_name)
        os.makedirs(dest_dir, exist_ok=True)
        if os.path.exists(dest_file):
            report_text += f"SKIPPING: (already archived) {source}\n"
        else:
            report_text += f"RETRIEVING: {source}\n"
            try:
                urllib.request.urlretrieve(source, dest_file)
            except urllib.error.URLError:
                report_text += f"\tFAILED: {source}\n"

payload = json.dumps({"report": report_text}).encode("utf-8")
req = urllib.request.Request(
    f"https://hooks.slack.com/triggers/{slack_token}",
    data=payload,
    headers={"Content-type": "application/json"},
    method="POST"
)
try:
    with urllib.request.urlopen(req, timeout=10):
        pass
except urllib.error.URLError as e:
    print(f"Error: failed to post to Slack: {e}", file=sys.stderr)
    raise SystemExit(1)

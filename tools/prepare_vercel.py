#!/usr/bin/env python3
"""Create a tiny Vercel source upload referring to this run's immutable artifact."""
import argparse
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parent.parent


def prepare(repository, run_id, commit, output):
    token = os.environ.get('GH_TOKEN') or os.environ.get('GITHUB_TOKEN')
    if not token:
        token = subprocess.check_output(['gh', 'auth', 'token'], text=True).strip()
    headers = {'Authorization': f'Bearer {token}', 'Accept': 'application/vnd.github+json',
               'X-GitHub-Api-Version': '2022-11-28'}
    api = f'https://api.github.com/repos/{repository}/actions'
    request = Request(f'{api}/runs/{run_id}/artifacts?per_page=100', headers=headers)
    with urlopen(request, timeout=30) as response:
        artifacts = json.load(response)['artifacts']
    matches = [item for item in artifacts if item['name'] == f'farlanding-web-{commit}'
               and not item['expired'] and str(item['workflow_run']['id']) == str(run_id)]
    if len(matches) != 1:
        raise ValueError('Expected exactly one release artifact from the current run')
    artifact = matches[0]
    digest = artifact.get('digest', '')
    if not re.fullmatch(r'sha256:[0-9a-f]{64}', digest):
        raise ValueError('GitHub did not supply a SHA-256 archive digest')
    output.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(ROOT / 'vercel.json', output / 'vercel.json')
    shutil.copyfile(ROOT / 'tools/vercel_build.py', output / 'build.py')
    (output / '.vercelignore').write_text('public/\n.vercel/\n')
    (output / 'artifact.json').write_text(json.dumps({
        'repository': repository, 'artifact_id': artifact['id'],
        'sha256': digest.removeprefix('sha256:'), 'commit': commit,
    }))
    print(f'Prepared Vercel source for tested artifact {artifact["id"]} at {commit}')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--repository', required=True)
    parser.add_argument('--run-id', required=True)
    parser.add_argument('--commit', required=True)
    parser.add_argument('--output', type=Path, default=Path('.vercel-source'))
    args = parser.parse_args()
    prepare(args.repository, args.run_id, args.commit, args.output)

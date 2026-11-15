"""Fast source-boundary and generated-audio integrity checks; no asset synthesis."""

import hashlib
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parent.parent
AUDIO_SUFFIXES = {'.wav', '.mp3', '.ogg'}


def check_audio(root: Path) -> list[str]:
    entries = json.loads((root / 'audio_src/manifest.json').read_text())['sounds']
    errors = []
    ids = set()
    paths = set()
    for entry in entries:
        name = entry['file']
        if entry['id'] in ids or name in paths:
            errors.append(f'duplicate audio manifest entry: {name}')
        ids.add(entry['id'])
        paths.add(name)
        path = root / name
        if not path.is_file():
            errors.append(f'missing audio: {name}')
        elif hashlib.sha256(path.read_bytes()).hexdigest() != entry['sha256']:
            errors.append(f'audio hash mismatch: {name}')
        if not Path(str(path) + '.import').is_file():
            errors.append(f'missing audio import settings: {name}')
    actual = {p.relative_to(root).as_posix() for p in (root / 'game/assets/audio').rglob('*')
              if p.suffix in AUDIO_SUFFIXES}
    for name in sorted(actual - paths):
        errors.append(f'untracked generated audio: {name}')
    return errors


def check_sim_dependencies(root: Path) -> list[str]:
    """Scenes may compose visuals; simulation scripts must not depend on adapters."""
    game = root / 'game'
    classes = {'Audio', 'UiTheme'}
    for layer in ('ui', 'audio', 'presentation'):
        for path in (game / layer).rglob('*.gd'):
            match = re.search(r'^class_name\s+(\w+)', path.read_text(), re.MULTILINE)
            if match:
                classes.add(match[1])
    forbidden = re.compile(r'\b(' + '|'.join(sorted(classes)) + r')\b') if classes else None
    errors = []
    for path in (game / 'sim').rglob('*.gd'):
        for number, line in enumerate(path.read_text().splitlines(), 1):
            code = line.split('#', 1)[0]
            if re.search(r'res://(?:ui|audio|presentation)/', code) or (
                    forbidden and forbidden.search(code)):
                errors.append(f'{path.relative_to(root)}:{number}: simulation depends on an adapter')
    return errors


def main() -> int:
    errors = check_audio(ROOT) + check_sim_dependencies(ROOT)
    for error in errors:
        print(error)
    print(f'Project integrity: {len(errors)} failures')
    return int(bool(errors))


if __name__ == '__main__':
    raise SystemExit(main())

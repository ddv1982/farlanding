#!/usr/bin/env python3
"""Invalidate model imports when their material-remapping script changes."""
import hashlib
from pathlib import Path
import re


def prepare(game: Path) -> int:
    importer = game / 'presentation/import/model_post_import.gd'
    stamp = game / '.godot/farlanding_importer.sha256'
    digest = hashlib.sha256(importer.read_bytes()).hexdigest()
    if stamp.exists() and stamp.read_text() == digest:
        return 0
    imported = (game / '.godot/imported').resolve()
    count = 0
    for settings in (game / 'assets/models').rglob('*.glb.import'):
        text = settings.read_text()
        if 'import_script/path="res://presentation/import/model_post_import.gd"' not in text:
            continue
        match = re.search(r'^path="res://([^"\n]+)"', text, re.MULTILINE)
        if match:
            output = (game / match[1]).resolve()
            if output.parent != imported or output.suffix != '.scn':
                raise ValueError(f'Unexpected model import output in {settings}')
            if output.exists():
                output.unlink()
                count += 1
    stamp.parent.mkdir(parents=True, exist_ok=True)
    stamp.write_text(digest)
    return count


if __name__ == '__main__':
    root = Path(__file__).resolve().parent.parent
    print(f'Invalidated {prepare(root / "game")} cached model imports after importer change')

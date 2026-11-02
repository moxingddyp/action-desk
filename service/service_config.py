"""Load explicit local configuration; no credentials or device defaults are bundled."""
import json
import os
from pathlib import Path

def load_config():
    path = os.environ.get('WORKBENCH_CONFIG')
    if not path: return {}
    value = json.loads(Path(path).read_text())
    if not isinstance(value, dict): raise ValueError('invalid_configuration')
    return value

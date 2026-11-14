import os
from dataclasses import dataclass
from pathlib import Path

BASE = Path(__file__).resolve().parents[2]

def xdg(name, default):
    value = Path(os.environ.get(name, str(Path.home() / default)))
    if not value.is_absolute(): raise ValueError(name + ': must be absolute')
    return value

@dataclass
class Paths:
    base: Path = BASE
    config: Path = None
    data: Path = None
    cache: Path = None
    state: Path = None
    hypr: Path = None
    def __post_init__(self):
        self.config = self.config or xdg('XDG_CONFIG_HOME', '.config') / 'wizarch'
        self.data = self.data or xdg('XDG_DATA_HOME', '.local/share') / 'wizarch/themes'
        self.cache = self.cache or xdg('XDG_CACHE_HOME', '.cache') / 'wizarch/themes'
        self.state = self.state or xdg('XDG_STATE_HOME', '.local/state') / 'wizarch/theme'
        self.hypr = self.hypr or xdg('XDG_CONFIG_HOME', '.config') / 'hypr/wizarch-theme.lua'
    @property
    def active(self): return self.state / 'active.json'
    @property
    def selection(self): return self.config / 'theme-selection.json'

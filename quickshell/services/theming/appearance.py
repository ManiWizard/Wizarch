"""Desktop preference adapter. No app-specific themes, shell commands or network."""
import ast
import base64
import configparser
import re
import stat
import subprocess
import os
from pathlib import Path
from .storage import atomic, remove
from .providers import durable_mkdir

SCHEMA = 'org.gnome.desktop.interface'
KEYS = ('color-scheme', 'gtk-theme')

class NoAppearance:
    """Explicit opt-out for offline initialization and isolated compositor tests."""
    def capture(self): return None
    def apply(self, mode): pass
    def restore(self, previous): pass

class DesktopAppearance:
    def __init__(self, run=None, theme_root=None, settings_file=None):
        self.run = run or subprocess.run
        self.settings_file = Path(settings_file) if settings_file is not None else Path(os.environ.get("XDG_CONFIG_HOME",str(Path.home()/".config")))/"gtk-3.0/settings.ini"
        if not self.settings_file.is_absolute(): raise ValueError("Desktop appearance: settings path must be absolute")
        self.theme_root = Path(theme_root) if theme_root is not None else Path(os.environ.get("XDG_DATA_HOME",str(Path.home()/".local/share")))/"themes"
        if not self.theme_root.is_absolute(): raise ValueError("Desktop appearance: theme root must be absolute")

    def call(self, *args):
        try:
            result = self.run(['gsettings', *args], capture_output=True, text=True, timeout=5, check=True)
        except (OSError, subprocess.SubprocessError) as error:
            raise RuntimeError('Desktop appearance: gsettings failed; check the session D-Bus and gsettings-desktop-schemas: ' + str(error)[:300]) from error
        # dconf can report an unsuccessful write on stderr with exit status zero.
        if result.stderr.strip():
            raise RuntimeError('Desktop appearance: ' + result.stderr.strip()[:300])
        return result.stdout.strip()

    def get(self, key):
        value = self.call('get', SCHEMA, key)
        if len(value) > 4096: raise ValueError('Desktop appearance: setting exceeds size limit')
        parsed = ast.literal_eval(value)
        if not isinstance(parsed, str): raise ValueError('Desktop appearance: expected string for ' + key)
        if key == 'color-scheme' and parsed not in ('default', 'prefer-light', 'prefer-dark'):
            raise ValueError('Desktop appearance: unsupported color-scheme')
        return value, parsed

    def capture(self):
        # Preserve both effective preferences; unrelated desktop keys are untouched.
        result = {}
        for key in KEYS:
            value, _ = self.get(key)
            if self.call('writable', SCHEMA, key) != 'true':
                raise RuntimeError('Desktop appearance: ' + key + ' is locked by desktop policy')
            result[key] = value
        raw=self.read_settings()
        result['gtkSettings']=base64.b64encode(raw).decode() if raw is not None else None
        return result

    def restore(self, previous):
        if previous is None: return  # Journals written before desktop integration.
        if not isinstance(previous, dict) or set(previous) not in (set(KEYS),set(KEYS)|{'gtkSettings'}):
            raise ValueError('Desktop appearance: incomplete recovery settings')
        errors = []
        for key in KEYS:
            try:
                value = previous[key]
                if not isinstance(value, str) or len(value)>4096 or not isinstance(ast.literal_eval(value),str):
                    raise ValueError('invalid saved setting')
                self.call('set', SCHEMA, key, value)
                if self.get(key)[1] != ast.literal_eval(value): raise RuntimeError('restored value was not accepted')
            except Exception as error: errors.append(key + ': ' + str(error))
        if 'gtkSettings' in previous:
            try:
                raw=previous['gtkSettings']
                if raw is None:
                    if self.settings_file.exists(): remove(self.settings_file)
                else:
                    raw=base64.b64decode(raw,validate=True)
                    if len(raw)>32768:raise ValueError('saved GTK settings exceed limit')
                    atomic(self.settings_file,raw)
            except Exception as error: errors.append('gtkSettings: '+str(error))
        if errors: raise RuntimeError('Desktop appearance rollback failed: ' + '; '.join(errors))

    def read_settings(self):
        try:fd=os.open(self.settings_file,os.O_RDONLY|os.O_NONBLOCK|os.O_CLOEXEC)
        except FileNotFoundError:return None
        try:
            if not stat.S_ISREG(os.fstat(fd).st_mode):raise ValueError('Desktop appearance: GTK settings must be a regular file')
            with os.fdopen(fd,'rb',closefd=False) as file:raw=file.read(32769)
            if len(raw)>32768:raise ValueError('Desktop appearance: GTK settings exceed 32 KiB')
        finally:os.close(fd)
        parser=configparser.ConfigParser(interpolation=None,delimiters=('=',),strict=True)
        parser.read_string(raw.decode('utf-8'))
        return raw

    def write_settings(self, theme, mode):
        if any(c in theme for c in ('\n','\r','\0')):raise ValueError('Desktop appearance: invalid GTK theme name')
        raw=self.read_settings();lines=raw.decode().splitlines(keepends=True) if raw else []
        values={'gtk-theme-name':theme,'gtk-application-prefer-dark-theme':'true' if mode=='dark' else 'false'}
        result=[];inside=False;found=False;pending=dict(values)
        for line in lines:
            header=re.fullmatch(r'\s*\[([^]]+)\]\s*',line.strip())
            if header:
                if inside:
                    result.extend(key+'='+value+'\n' for key,value in pending.items());pending={}
                inside=header[1]=='Settings';found=found or inside
            match=re.match(r'\s*([^=]+?)\s*=',line)
            if inside and match and match[1] in values:
                key=match[1];result.append(key+'='+values[key]+'\n');pending.pop(key,None)
            else:result.append(line)
        if result and not result[-1].endswith('\n'):result[-1]+='\n'
        if not found:result.append('[Settings]\n')
        result.extend(key+'='+value+'\n' for key,value in pending.items())
        content=''.join(result).encode()
        if content!=raw:durable_mkdir(self.settings_file.parent);atomic(self.settings_file,content)

    def ensure_native_themes(self):
        # GTK embeds the Adwaita CSS, but some distros omit the named dark alias.
        # Import those resources under our own names; no copied third-party CSS.
        for name, variant in (('Wizard-Adwaita',''),('Wizard-Adwaita-dark','-dark')):
            folder=self.theme_root/name/'gtk-3.0'
            css=folder/'gtk.css'
            content='/* Wizard desktop mode adapter: GTK built-in resource. */\n@import url("resource:///org/gtk/libgtk/theme/Adwaita/gtk-contained'+variant+'.css");\n'
            root=self.theme_root.resolve()
            if not css.resolve().is_relative_to(root): raise ValueError('Desktop appearance: theme alias escapes data directory')
            if css.exists():
                # These are static installation assets, never overwrite user content.
                fd=os.open(css,os.O_RDONLY|os.O_NONBLOCK|os.O_CLOEXEC)
                try:
                    if not stat.S_ISREG(os.fstat(fd).st_mode):raise ValueError('Desktop appearance: theme alias must be a regular file')
                    existing=os.read(fd,1025)
                finally:os.close(fd)
                if existing!=content.encode():raise ValueError('Desktop appearance: reserved theme alias has different content: '+str(css))
            else:
                durable_mkdir(folder);atomic(css,content)

    def apply(self, mode):
        if mode not in ('light', 'dark'): raise ValueError('Desktop appearance: mode must be light or dark')
        _, theme = self.get('gtk-theme')
        # Supported native pair, bundled by GTK. Keep a custom theme rather than
        # guessing or replacing it; its own dark/light support is app dependent.
        desired = {'color-scheme': 'prefer-' + mode}
        if theme in ('Adwaita', 'Adwaita-dark', 'Wizard-Adwaita', 'Wizard-Adwaita-dark'):
            self.ensure_native_themes()
            desired['gtk-theme'] = 'Wizard-Adwaita-dark' if mode == 'dark' else 'Wizard-Adwaita'
        for key, value in desired.items():
            _, current = self.get(key)
            if current != value:
                if self.call('writable', SCHEMA, key) != 'true':
                    raise RuntimeError('Desktop appearance: ' + key + ' is locked by desktop policy')
                self.call('set', SCHEMA, key, repr(value))
                if self.get(key)[1] != value: raise RuntimeError('Desktop appearance: ' + key + ' write was not accepted')
        self.write_settings(desired.get('gtk-theme',theme),mode)

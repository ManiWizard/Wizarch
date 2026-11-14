import re, warnings, xml.etree.ElementTree as ET
from pathlib import Path
from jsonschema import Draft202012Validator, validators
StrictValidator = validators.extend(Draft202012Validator,type_checker=Draft202012Validator.TYPE_CHECKER.redefine("integer",lambda checker,value:type(value) is int))
from PIL import Image
from .paths import BASE
from .storage import read_json

SCHEMAS = BASE / 'schemas'
ROLES = ['primary','onPrimary','primaryContainer','onPrimaryContainer','inversePrimary']
for family in ('secondary','tertiary'):
    ROLES += [family,'on'+family.title(),family+'Container','on'+family.title()+'Container']
for family in ('primary','secondary','tertiary'):
    ROLES += [family+'Fixed',family+'FixedDim','on'+family.title()+'Fixed','on'+family.title()+'FixedVariant']
ROLES += ['error','onError','errorContainer','onErrorContainer','surface','onSurface','onSurfaceVariant','surfaceDim','surfaceBright','surfaceContainerLowest','surfaceContainerLow','surfaceContainer','surfaceContainerHigh','surfaceContainerHighest','inverseSurface','inverseOnSurface','outline','outlineVariant','shadow','scrim','surfaceTint']

_VALIDATORS = {}
def validate(kind, data):
    if kind not in _VALIDATORS:
        schema = read_json(SCHEMAS / (kind + '.schema.json'))
        Draft202012Validator.check_schema(schema)
        _VALIDATORS[kind] = StrictValidator(schema)
    errors = sorted(_VALIDATORS[kind].iter_errors(data), key=lambda e: str(list(e.absolute_path)))
    if errors:
        raise ValueError('; '.join(f"{kind}.{'.'.join(map(str,e.absolute_path)) or '$'}: {e.message}" for e in errors[:8]))
    if kind in ('pack','catalog','sources'):
        entries=data.get('wallpapers',data.get('packs',data.get('sources',[])))
        ids=[entry['id'] for entry in entries]
        if len(ids)!=len(set(ids)): raise ValueError(kind+'.id: duplicate stable IDs')
    return data

def contained(root, relative):
    if not isinstance(relative, str) or not relative or '\\' in relative or Path(relative).is_absolute() or '..' in Path(relative).parts:
        raise ValueError('asset.path: expected a portable relative path without traversal')
    p = (root / relative).resolve(strict=True)
    if not p.is_relative_to(root.resolve()) or not p.is_file(): raise ValueError('asset.path: escapes pack root or is not a file')
    return p

def asset(root, relative, legacy_svg=False):
    p = contained(root, relative)
    if p.stat().st_size > 32 * 1024 * 1024: raise ValueError('asset.path: exceeds 32 MiB')
    if p.suffix.lower() == '.svg':
        if not legacy_svg: raise ValueError('asset.path: new SVG content is unsupported; use PNG/JPEG/WebP')
        raw = p.read_bytes()
        if len(raw)>256*1024 or re.search(br'<!DOCTYPE|<!ENTITY|<script|<foreignObject|\bon\w+\s*=|url\s*\(',raw,re.I): raise ValueError('asset.path: unsafe legacy SVG')
        doc = ET.fromstring(raw)
        for element in doc.iter():
            if element.tag.split('}')[-1] not in {'svg','g','path','rect','circle','ellipse','line','polyline','polygon','defs','linearGradient','radialGradient','stop','title','desc'}: raise ValueError('asset.path: unsupported legacy SVG element')
            if any('href' in k or ':' in v for k,v in element.attrib.items()): raise ValueError('asset.path: external legacy SVG reference')
        for key in ('width','height'):
            if float(doc.attrib.get(key,'0'))>8192: raise ValueError('asset.path: SVG too large')
    else:
        if p.suffix.lower() not in ('.png','.jpg','.jpeg','.webp'): raise ValueError('asset.path: unsupported format')
        with warnings.catch_warnings():
            warnings.simplefilter('error')
            with Image.open(p) as image:
                if image.format not in ('PNG','JPEG','WEBP') or image.width>8192 or image.height>8192 or image.width*image.height>33554432 or getattr(image,'n_frames',1)!=1:
                    raise ValueError('asset.path: unsupported decoded format, dimensions, or animation')
                image.verify()
            with Image.open(p) as image: image.load()
    return p.as_uri()


def bounded_files(root, maximum=128):
    import os
    files=[]; count=0
    for directory, directories, names in os.walk(root,followlinks=False):
        count+=len(directories)+len(names)
        if count>maximum*4: raise ValueError('pack: excessive directory entries')
        for name in names:
            path=Path(directory)/name
            if not path.is_file(): raise ValueError('pack: non-file content')
            files.append(path)
            if len(files)>maximum: raise ValueError('pack: exceeds file count bound')
    return files

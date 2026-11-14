import hashlib, importlib.metadata, json, re, math
from .validation import ROLES, validate
from .storage import atomic, read_json

GENERATOR = {'library':'material-color-utilities','version':'0.2.6','specification':'Material 3 2021 dynamic roles / tonal surfaces','variant':'tonal-spot-three-key','license':'Apache-2.0'}

def generate(keys, contrast=0, monochrome=False):
    if monochrome and set(keys)!={"primary"}: raise ValueError("monochrome: only the primary reference is allowed; explicit secondary/tertiary must use the three-key variant")
    import material_color_utilities as m
    if importlib.metadata.version('material-color-utilities') != GENERATOR['version']: raise ValueError('generator: install material-color-utilities==0.2.6')
    variant = m.Variant.MONOCHROME if monochrome else m.Variant.TONALSPOT
    t = m.theme_from_color(keys['primary'], contrast, variant)
    schemes = {}
    for mode in ('light','dark'):
        s = getattr(t.schemes, mode)
        # Explicit keys use their own HCT hue/chroma; omitted keys retain the pinned variant defaults.
        for family in ('primary','secondary','tertiary'):
            if family in keys and not monochrome: setattr(s, family+'_palette',m.TonalPalette(m.Hct(keys[family])))
        schemes[mode] = {role:getattr(s, re.sub(r'([A-Z])',lambda x:'_'+x[1].lower(),role)) for role in ROLES}
    result = {'schemaVersion':1,'generator':{**GENERATOR,'variant':'monochrome' if monochrome else GENERATOR['variant'],'keys':keys,'contrast':contrast},'schemes':schemes}
    validate('palette',result); check_schemes(schemes)
    return result

def luminance(color):
    rgb = [int(color[i:i+2],16)/255 for i in (1,3,5)]
    linear = [c/12.92 if c<=.04045 else ((c+.055)/1.055)**2.4 for c in rgb]
    return sum(c*w for c,w in zip(linear,(.2126,.7152,.0722)))

def ratio(a,b):
    x,y = sorted((luminance(a),luminance(b))); return (y+.05)/(x+.05)

def blend(fg,bg,alpha):
    return '#'+''.join(f'{math.floor(int(fg[i:i+2],16)*alpha+int(bg[i:i+2],16)*(1-alpha)+.5):02x}' for i in (1,3,5))

def state_layer(bg, fg, alpha):
    while alpha>0 and ratio(fg,blend(fg,bg,alpha))<4.5: alpha=max(0,alpha-.01)
    return blend(fg,bg,alpha)

def contrast_results(c):
    pairs = []
    for family in ('primary','secondary','tertiary','error'):
        for suffix in ('','Container'):
            bg=family+suffix; pairs.append((f'on{family.title()}{suffix}',bg,4.5))
    for family in ('primary','secondary','tertiary'):
        for fg in ('on'+family.title()+'Fixed','on'+family.title()+'FixedVariant'):
            for bg in (family+'Fixed',family+'FixedDim'): pairs.append((fg,bg,4.5))
    for bg in ('surface','surfaceDim','surfaceBright','surfaceContainerLowest','surfaceContainerLow','surfaceContainer','surfaceContainerHigh','surfaceContainerHighest'):
        pairs += [('onSurface',bg,4.5),('onSurfaceVariant',bg,4.5),('primary',bg,3),('outline',bg,3)]
    pairs += [('inverseOnSurface','inverseSurface',4.5),('error','surfaceContainer',3),('error','surfaceContainerHigh',4.5)]
    results=[{'foreground':f,'background':b,'ratio':ratio(c[f],c[b]),'minimum':minimum} for f,b,minimum in pairs]
    for bg,fg in [('primary','onPrimary'),('surfaceContainer','onSurface'),('surfaceContainerHigh','onSurface'),('surfaceContainerHighest','onSurface'),('secondaryContainer','onSecondaryContainer'),('primaryContainer','onPrimaryContainer'),('tertiaryContainer','onTertiaryContainer')]:
        for state,alpha in [('hover',.08),('focus',.10),('pressed',.10)]:
            results.append({'foreground':fg,'background':bg+':'+state,'ratio':ratio(c[fg],state_layer(c[bg],c[fg],alpha)),'minimum':4.5})
    # Shared neutral hover aliases also host secondary text and primary focus borders.
    for bg in ('surfaceContainerHigh','surfaceContainerHighest'):
        for state,alpha in [('hover',.08),('focus',.10),('pressed',.10)]:
            resolved=state_layer(c[bg],c['onSurface'],alpha)
            for fg,minimum in [('onSurfaceVariant',4.5),('primary',3)]:
                results.append({'foreground':fg,'background':bg+':'+state,'ratio':ratio(c[fg],resolved),'minimum':minimum})
    return results

def check_schemes(schemes):
    failures=[]
    for mode,c in schemes.items():
        for r in contrast_results(c):
            if r['ratio']+1e-6<r['minimum']: failures.append(f"{mode}.{r['foreground']}/{r['background']}: {r['ratio']:.2f} < {r['minimum']}")
    if failures: raise ValueError('contrast: '+ '; '.join(failures[:12]))

def resolve(manifest, root, cache):
    color = manifest['color']
    if color['type']=='roles':
        from .validation import contained
        result = validate('palette',read_json(contained(root,color['path'])))
    else:
        key = hashlib.sha256(json.dumps({'input':color,'generator':GENERATOR},sort_keys=True).encode()).hexdigest()
        path=cache/(key+'.json')
        expected={**GENERATOR,'variant':'monochrome' if color.get('variant')=='monochrome' else GENERATOR['variant'],'keys':color['keys'],'contrast':color.get('contrast',0)}
        result=None
        if path.exists():
            try:
                cached=validate('palette',read_json(path))
                if cached.get('generator')!=expected or set(cached['schemes'])!={'light','dark'}: raise ValueError('cache generator/input mismatch')
                check_schemes(cached['schemes']); result=cached
            except (OSError,ValueError,KeyError): path.unlink(missing_ok=True)
        if result is None:
            try: result=generate(color['keys'],color.get('contrast',0),color.get('variant')=='monochrome')
            except (ImportError,importlib.metadata.PackageNotFoundError) as e:
                raise ValueError('Palette generation unavailable: install the pinned theme runtime; committed resolved snapshots remain usable') from e
            atomic(path,result)
        files=sorted(cache.glob('*.json'),key=lambda p:p.stat().st_mtime)
        for p in files[:-32]: p.unlink()
    if color['type']=='keys':
        # Generate/cache both, but expose exactly the pack's declared supported modes.
        result={**result,'schemes':{mode:result['schemes'][mode] for mode in manifest['modes']}}
    if set(result['schemes'])!=set(manifest['modes']): raise ValueError('color.schemes: must match supported modes exactly')
    check_schemes(result['schemes'])
    return result


def import_export(value):
    validate('material-export',value)
    result={'schemaVersion':1,'schemes':{mode:{r:c[r] for r in ROLES} for mode,c in value['schemes'].items()}}
    if value.get('generator'): result['generator']=value['generator']
    check_schemes(result['schemes']);validate('palette',result)
    return result

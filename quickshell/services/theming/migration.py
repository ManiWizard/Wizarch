"""Bounded read-only adapter for the historical Wizard manifests."""
from .validation import ROLES, validate

def legacy(data):
    allowed={'id','name','description','colors','assets','hyprland','wallpaper','logo'}
    if set(data)-allowed: raise ValueError('legacy: unknown fields')
    h=data.get('hyprland',{})
    if set(h)-{'rounding','borderSize','activeBorder','inactiveBorder'}: raise ValueError('legacy.hyprland: unknown fields; snippets/hooks are forbidden')
    for key,lo,hi in [('rounding',0,30),('borderSize',1,5)]:
        if key in h and (type(h[key]) is not int or not lo<=h[key]<=hi): raise ValueError('legacy.hyprland.'+key+': wrong type/range')
    import re
    for key in ['activeBorder','inactiveBorder']:
        if key in h and (not isinstance(h[key],str) or not re.fullmatch('#[a-fA-F0-9]{6}',h[key])): raise ValueError('legacy.hyprland.'+key+': invalid color')
    colors=data.get('colors',{})
    if set(ROLES)-set(colors): raise ValueError('legacy.colors: missing canonical roles')
    extra=set(colors)-set(ROLES)-{'background','onBackground','surfaceVariant','divider','hoverSurface','hoverActiveSurface'}
    if extra: raise ValueError('legacy.colors: unknown fields '+str(sorted(extra)))
    schemes={'dark':{r:colors[r] for r in ROLES}}
    validate('palette',{'schemaVersion':1,'schemes':schemes})
    assets=data.get('assets',{})
    if set(assets)-{'wallpaper','wallpapers','logo'}: raise ValueError('legacy.assets: unknown fields')
    entries=assets.get('wallpapers') or [{'name':'Original','path':assets['wallpaper']}]
    if not isinstance(entries,list) or len(entries)>32: raise ValueError('legacy.assets.wallpapers: invalid list')
    if any(not isinstance(e,dict) or set(e)!={'name','path'} for e in entries): raise ValueError('legacy.assets.wallpapers: unknown fields')
    wallpapers=[{'id':'original' if e['path']==assets['wallpaper'] else 'alternative-'+str(i),'name':e['name'],'path':e['path']} for i,e in enumerate(entries)]
    manifest={'schemaVersion':1,'id':data['id'],'name':data['name'],'version':'1.0.0','description':data.get('description',''),'modes':['dark'],'defaultMode':'dark','color':{'type':'roles','path':'legacy-resolved.json'},'wallpapers':wallpapers,'defaultWallpaper':'original'}
    if assets.get('logo'): manifest['logo']=assets['logo']
    validate('pack',manifest)
    return manifest, {'schemaVersion':1,'schemes':schemes}

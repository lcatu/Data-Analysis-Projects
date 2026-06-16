import os, glob, xml.etree.ElementTree as ET
ns = {'DTS':'www.microsoft.com/SqlServer/Dts'}
packages = sorted(glob.glob('*.dtsx'))
print('packages:', packages)
for pkg in packages:
    print('\n===', pkg)
    tree = ET.parse(pkg)
    root = tree.getroot()
    for cm in root.findall('.//DTS:ConnectionManager', ns):
        name = cm.get('{www.microsoft.com/SqlServer/Dts}refId') or cm.get('DTS:refId') or cm.get('refId') or cm.get('Name') or cm.get('DTS:Name')
        p = cm.find('.//DTS:Property[@DTS:Name="ConnectionString"]', ns)
        cs = p.text if p is not None else ''
        print('CM:', name, cs[:160])
    for exe in root.findall('.//DTS:Executable', ns):
        desc = exe.get('{www.microsoft.com/SqlServer/Dts}Description') or exe.get('DTS:Description')
        etype = exe.get('{www.microsoft.com/SqlServer/Dts}ExecutableType') or exe.get('DTS:ExecutableType')
        name = exe.get('{www.microsoft.com/SqlServer/Dts}Name') or exe.get('DTS:Name')
        if desc or etype or name:
            print('Task:', name, desc, etype)
    for prop in root.findall('.//DTS:Property', ns):
        nm = prop.get('{www.microsoft.com/SqlServer/Dts}Name') or prop.get('DTS:Name')
        if nm and nm.lower() in ('sqlcommand','sqlcommandtext') and prop.text and prop.text.strip():
            txt = prop.text.strip().replace('\n',' ').replace('  ',' ')
            print('SQL:', nm, txt)

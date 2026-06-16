import glob, xml.etree.ElementTree as ET
ns = {'DTS':'www.microsoft.com/SqlServer/Dts'}
for pkg in sorted(glob.glob('*.dtsx')):
    tree = ET.parse(pkg)
    root = tree.getroot()
    print('\nPACKAGE:', pkg)
    for cm in root.findall('.//DTS:ConnectionManager', ns):
        name = cm.get('{www.microsoft.com/SqlServer/Dts}refId') or cm.get('DTS:refId') or cm.get('refId') or cm.get('Name') or cm.get('DTS:Name')
        cs = ''
        p = cm.find('.//DTS:Property[@DTS:Name="ConnectionString"]', ns)
        if p is not None and p.text:
            cs = p.text.strip()
        if cs:
            print('  CM:', name, cs)
        else:
            print('  CM:', name)
    for pipeline in root.findall('.//DTS:Executable[@DTS:ExecutableType="Microsoft.Pipeline"]', ns):
        taskname = pipeline.get('{www.microsoft.com/SqlServer/Dts}Name') or pipeline.get('DTS:Name')
        print('  PIPELINE TASK:', taskname)
        for component in pipeline.findall('.//component'):
            cname = component.get('name')
            cclass = component.get('componentClassID')
            print('    COMPONENT:', cname, cclass)
            for prop in component.findall('.//property'):
                pname = prop.get('name')
                if pname in ('SqlCommand','AccessMode','OpenRowset','OpenRowsetVariable','SqlCommandVariable','Connection','ConnectionManagerID','ConnectionManagerRefId','Expression','FriendlyExpression'):
                    val = (prop.text or '').strip().replace('\n',' ').replace('  ',' ')
                    print('      PROP', pname, '=>', val)
            for col in component.findall('.//output/columns/column'):
                if col.get('name'):
                    print('      OUTCOL', col.get('name'), 'dataType', col.get('dataType') or col.get('dataTypeCode'))
            for col in component.findall('.//input/columns/column'):
                if col.get('name'):
                    print('      INCOL', col.get('name'), 'dataType', col.get('dataType') or col.get('dataTypeCode'))
    for prop in root.findall('.//DTS:Property[@DTS:Name="SqlCommand"]', ns) + root.findall('.//DTS:Property[@DTS:Name="SqlCommandText"]', ns):
        if prop.text and prop.text.strip():
            print('  SQLCMD:', prop.text.strip().replace('\n',' ').replace('  ',' '))

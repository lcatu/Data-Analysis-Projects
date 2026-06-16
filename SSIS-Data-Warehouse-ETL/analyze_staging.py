import xml.etree.ElementTree as ET
ns = {'DTS':'www.microsoft.com/SqlServer/Dts'}
tree = ET.parse('Load_Staging.dtsx')
root = tree.getroot()

print('=== LOAD_STAGING CONTROL FLOW ===\n')

# Find all tasks
task_list = []
for exe in root.findall('.//DTS:Executable', ns):
    name = exe.get('{www.microsoft.com/SqlServer/Dts}Name') or 'Unknown'
    etype = exe.get('{www.microsoft.com/SqlServer/Dts}ExecutableType') or 'Unknown'
    task_list.append((name, etype))

# Print each task
for idx, (name, etype) in enumerate(task_list, 1):
    if 'Pipeline' in etype:
        print(f'{idx}. DATA FLOW: {name}')
    elif 'ExecuteSQLTask' in etype:
        print(f'{idx}. EXECUTE SQL: {name}')
    elif 'Sequence' in etype:
        print(f'{idx}. CONTAINER: {name}')
    else:
        print(f'{idx}. {etype}: {name}')

# Now extract SQL commands
print('\n=== SQL COMMANDS ===\n')
cmd_idx = 1
for prop in root.findall('.//DTS:Property[@DTS:Name="SqlCommand"]', ns):
    if prop.text:
        sql = prop.text.strip().replace('\n', ' ').replace('  ', ' ')
        print(f'SQL {cmd_idx}: {sql[:250]}...\n')
        cmd_idx += 1

"""Exercise the real executables and inspect every geometry/metadata field.

Uses only Python's standard library. If vtk is installed, also reads the final
result through vtkPolyDataReader (the same data model used by ParaView).
"""
from pathlib import Path
import subprocess
import sys

root = Path(__file__).resolve().parents[2]
bin_dir = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else root / 'bin'
add = bin_dir / 'mesh_add'
domain = bin_dir / 'mesh_domain'


def run(exe, args, source=None, success=True):
    p = subprocess.run([str(exe), *args.split()], input=source, text=True, capture_output=True)
    if success:
        assert p.returncode == 0, p.stderr
        assert p.stdout.startswith('# vtk DataFile'), p.stdout
        return p.stdout
    assert p.returncode != 0, args
    assert p.stdout == '', 'Failure emitted partial VTK'
    assert p.stderr.strip(), 'Missing diagnostic'


def parse(text):
    lines = text.splitlines()
    assert lines[0] == '# vtk DataFile Version 3.0'
    assert lines[2:4] == ['ASCII', 'DATASET POLYDATA']
    t = iter(' '.join(lines[4:]).split())
    arrays = {}; cells = {}; points = []; assoc = 0; nt = 0
    for key in t:
        if key == 'POINTS':
            n = int(next(t)); dtype = next(t)
            points = [float(next(t)) for _ in range(3*n)]
        elif key in ('VERTICES', 'LINES', 'POLYGONS'):
            n = int(next(t)); total = int(next(t)); records = []
            for _ in range(n):
                m = int(next(t)); records.append([int(next(t)) for _ in range(m)])
            assert sum(len(c)+1 for c in records) == total
            cells[key] = records
        elif key in ('POINT_DATA', 'CELL_DATA'):
            assoc = 1 if key == 'POINT_DATA' else 2
            nt = int(next(t))
        elif key == 'FIELD':
            group = next(t); count = int(next(t))
            for _ in range(count):
                name = next(t); nc = int(next(t)); n = int(next(t)); dtype = next(t)
                arrays[assoc, name] = (dtype, nc, n, [next(t) for _ in range(nc*n)])
        elif key == 'SCALARS':
            name = next(t); dtype = next(t); nc = int(next(t))
            assert next(t) == 'LOOKUP_TABLE' and next(t) == 'default'
            arrays[assoc, name] = (dtype, nc, nt, [next(t) for _ in range(nc*nt)])
        else:
            raise AssertionError(key)
    return points, cells, arrays


base = run(domain, 'lx=100 ly=100 sl=1.')
# Unknown metadata with multiple components/tuples and precision-sensitive tokens.
meta = base.replace('FIELD FieldData 3', 'FIELD FieldData 4').replace(
    'POINTS 4 double', 'future_calibration 2 2 double\n1.2345678901234567 2.0 3.0 4.0\nPOINTS 4 double')
source = run(add, 'primitive=line id=1 x1=0 y1=60 x2=80 y2=100', meta)
source = run(add, 'primitive=point x=50 y=50', source)
source = run(add, 'primitive=line id=2 x1=0 y1=70 x2=60 y2=100', source)
source = run(add, 'primitive=line id=3 x1=0 y1=50 x2=100 y2=90', source)
points, cells, arrays = parse(source)
assert len(points)//3 == 11
assert cells['VERTICES'] == [[6]]  # inserted after cable 1's two new points
assert len(cells['LINES']) == 7
assert arrays[2, 'sensor_id'][3] == ['0','0','0','0','0','1','2','3']
assert arrays[2, 'is_domain_boundary'][3] == ['0','1','1','1','1','0','0','0']
for key, value in parse(meta)[2].items():
    if key[0] == 0:
        assert arrays[key] == value, f'Metadata changed: {key}'
# Coincident existing corner is reused, not duplicated.
corner = run(add, 'primitive=point id=9 x=0 y=0', source)
assert len(parse(corner)[0]) == len(points)
assert parse(corner)[2][2, 'sensor_id'][3][:2] == ['0','9']
# Unknown point attributes survive when adding a vertex at an existing corner.
point_data = base + '\nPOINT_DATA 4\nSCALARS future_point int 1\nLOOKUP_TABLE default\n10 20 30 40\n'
shared = run(add, 'primitive=point x=0 y=0', point_data)
assert parse(shared)[2][1, 'future_point'][3] == ['10', '20', '30', '40']
run(add, 'primitive=point x=20 y=20', point_data, False)
# A second cable can share the first cable's endpoint without another coordinate.
shared = run(add, 'primitive=line id=4 x1=0 y1=60 x2=25 y2=25', source)
assert len(parse(shared)[0]) == len(points) + 3
# Unknown cell values cannot be invented: reject without any stdout.
unknown = base + '\nSCALARS future_quantity double 1\nLOOKUP_TABLE default\n1 2 3 4\n'
run(add, 'primitive=point x=50 y=50', unknown, False)
for args in (
    'primitive=line id=1 x1=0 y1=0 x2=10 y2=10',  # duplicate sensor ID
    'primitive=point x=101 y=50',
    'primitive=point x=50 y=50',  # duplicate vertex constraint
    'primitive=line id=4 x1=10 y1=10 x2=10 y2=10',
    'primitive=point x=1 y=2 typo=3',
    'primitive=point x=1 x=2 y=3',
    'primitive=point x=NaN y=2',
):
    run(add, args, source, False)
run(add, 'primitive=point x=20 y=20', base.replace('ASCII', 'BINARY'), False)
run(add, 'primitive=point x=20 y=20', base[:base.index('LINES')], False)
run(add, 'primitive=point x=20 y=20', base + '\nUNSUPPORTED_SECTION\n', False)
# A true shell pipeline checks stdin/stdout interoperability, not just files.
p1 = subprocess.Popen([str(domain), 'lx=100', 'ly=100', 'sl=1.'], stdout=subprocess.PIPE)
p2 = subprocess.Popen([str(add), 'primitive=point', 'x=50', 'y=50'], stdin=p1.stdout,
                      stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
p1.stdout.close()
out, err = p2.communicate()
assert p1.wait() == 0 and p2.returncode == 0, err
assert len(parse(out)[0]) == 15
try:
    from vtkmodules.vtkIOLegacy import vtkPolyDataReader
except ImportError:
    print('VTK library check skipped (optional Python vtk package not installed).')
else:
    reader = vtkPolyDataReader()
    reader.ReadFromInputStringOn(); reader.SetInputString(source)
    reader.ReadAllScalarsOn(); reader.ReadAllFieldsOn(); reader.Update()
    data = reader.GetOutput()
    assert data.GetNumberOfPoints() == 11
    assert data.GetNumberOfCells() == 8
    assert data.GetFieldData().GetArray('future_calibration').GetNumberOfTuples() == 2
    assert data.GetFieldData().GetArray('domain_bounds').GetNumberOfComponents() == 6
    assert data.GetCellData().GetArray('sensor_id').GetTuple1(5) == 1
    print('PASS: VTK library reads geometry, metadata and sensor attributes.')
print('PASS: chained additions, attribute alignment, metadata preservation and rejection cases.')

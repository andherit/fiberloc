mesh_add -- append one point constraint or straight cable to a VTK stream

Build from the repository root:
  make -C mesh-domain
  make -C mesh-add

Example (case 2 geometry, fixed centre, no earthquake yet):
  ./bin/mesh_domain lx=100 ly=100 sl=1. \
    | ./bin/mesh_add primitive=point x=50 y=50 \
    | ./bin/mesh_add primitive=line id=1 x1=0 y1=60 x2=80 y2=100 \
    | ./bin/mesh_add primitive=line id=2 x1=0 y1=70 x2=60 y2=100 \
    | ./bin/mesh_add primitive=line id=3 x1=0 y1=50 x2=100 y2=90 \
    > geometry.vtk

geometry.vtk can be opened in ParaView. This is geometry, not a triangular
mesh; mesh_generate is the later stage that will perform Gmsh meshing.
Use set -o pipefail in Bash when scripting pipelines to detect upstream failures.
Never redirect output to the same file being used as input.

Arguments:
  primitive=point x=<value> y=<value> [z=0] [id=0]
  primitive=line id=<positive integer> x1=<value> y1=<value> x2=<value> y2=<value>

A point with id=0 is an embedded geometric constraint, e.g. the fixed centre.
A point with a positive ID is a point sensor. A line is a cable sensor, lies
at z=0, and requires a positive ID. Positive IDs are unique across both kinds.
Coordinates must lie inside domain_bounds. A rectangle is convex, so checking
both endpoints also checks that the entire straight segment stays inside it.

Exactly coincident existing coordinates are reused, without rounding or moving
them. Duplicate point primitives, duplicate segments (also reversed), duplicate
sensor IDs and zero-length lines are rejected. Multiple lines may share an
endpoint. Intersections and endpoints lying inside boundary edges are left for
mesh_generate to split: mesh_add does not silently alter existing topology.

Data preservation:
- stdin/stdout: legacy ASCII VTK 3.0 POLYDATA. Diagnostics/help go to stderr.
- src/vtk_io.f90 reads/writes geometry plus numeric arrays independently of names.
- Dataset FIELD arrays retain names, groups, shapes, types and numeric tokens.
- Existing point coordinates and attributes retain their tokens; new coordinates
  are double precision (float geometry is promoted when points are added).
- VERTICES precede LINES and POLYGONS in VTK cell order. Existing cell attributes
  are shifted consistently when inserting a vertex or line.
- is_domain_boundary and sensor_id are extended with defined values only.
- Unknown cell-associated arrays cause a clear error: no invented values for the
  new cell. Point-associated arrays are preserved if no new coordinate is needed;
  otherwise the edit fails for the same reason. Future explicit fill policies
  can extend this behavior, but never silently discard data or assume zero.
- Formatting may change; the information and numeric precision do not.

Reader subset:
  POINTS float/double; packed VERTICES, LINES, POLYGONS; numeric FIELD arrays;
  SCALARS with default lookup table, VECTORS, NORMALS and TENSORS.
  Numeric types: int, short, unsigned_short, char, unsigned_char, float, double.
  Integer tokens must fit the default Fortran integer range; real tokens must
  use decimal E/e or D/d notation. Strings, binary, modern offsets/connectivity,
  custom lookup tables and other unsupported sections are explicitly rejected.
  No rewinding/seeking: input can be an actual Unix pipe.

Layout:
  mesh-add/mesh_add.f90: command-line parsing using unchanged SGRAC forparse.
  src/fiberloc_geometry.f90: geometry changes, IDs, domain checks, data alignment.
  src/vtk_io.f90: shared representation, reader and writer; original writer API
  remains available for mesh_domain.

Tests:
  make -C mesh-add test
Requires Python 3 for the test driver, not for the executables. The Python vtk
package is optional; if present, a real VTK reader also validates the result.
The tests cover chained additions, point insertion after lines, shared corner
coordinates, unknown metadata precision, invalid inputs, unsupported fields,
empty stdout on rejection and a real OS pipeline.

Validated with gfortran 13.3 and -fcheck=all, and Python VTK's legacy reader.

Executables:
Make now writes executables to the shared repository bin/ directory. Object
and module files remain in each program's build/ directory. Each clean target
removes only its own executable, not the other programs in bin/.
Optionally override BIN_DIR with an absolute path when invoking make.

From the repository root, add bin/ to PATH for the current shell:
  export PATH="$PWD/bin:$PATH"
Then run mesh_domain and mesh_add directly. For persistent use, add the same
export with your actual absolute repository path to ~/.bashrc.

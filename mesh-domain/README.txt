mesh_domain -- first brick of the geometry pipeline

Build and run (gfortran):
  make
  ./mesh_domain lx=100 ly=100 sl=1. > domain.vtk
  ./mesh_domain --help

All three arguments are required, finite and strictly positive.
The domain is [0,lx] x [0,ly], z=0. sl is the target triangle edge length
for the future mesh_generate stage, not a grid spacing applied here.
Coordinate units are user-defined and must be consistent throughout.

The program writes legacy ASCII VTK POLYDATA exclusively to stdout.
Help and failures go to stderr. It reads no stdin and creates no side files.
Open domain.vtk in ParaView to see the four boundary edges.
No meshing, sensors, centre point or earthquake are created at this stage.
The fixed centre point (50,50 for the 100x100 example) belongs in mesh_add.

Output contract, schema version 1:
- Leading dataset FIELD block: schema_version, domain_bounds, mesh_size.
- domain_bounds has six components: xmin xmax ymin ymax zmin zmax.
- Four counterclockwise corners and four two-node LINES, zero-based IDs.
- CELL_DATA is_domain_boundary = 1 for each boundary edge.
- CELL_DATA sensor_id = 0 for non-sensors.
Later geometry stages must preserve metadata and maintain aligned cell arrays.
In POLYDATA, VERTICES precede LINES in the global cell-data ordering.
The geometry-only VTK is not yet a triangle-only trilat-time input.

Reuse:
The bundled vendor/forparse.f90 is an unchanged copy of
andherit/sgrac, sgrac_geometry/src/forparse.f90, main commit
cdfba4848a08bbd00ce8a74acdc7f91ea7c244b7.
Its upstream MIT licence is included as vendor/SGRAC-LICENSE.
To use your own copy:
  make FORPARSE_SRC=/absolute/path/to/forparse.f90
Use make clean first when switching parser sources.

parse_arg is reused for argument extraction; its string overload allows
conversion directly to real64. Small additional checks catch unknown keys,
duplicates, overlong arguments, malformed values and non-positive lengths.
The SGRAC triangle writer is not used: this stage writes boundary lines,
not a triangular mesh, and does not need LAT_mesh or Gmsh.

Shared VTK writing:
../src/vtk_io.f90 now owns the legacy ASCII serialization. mesh_domain keeps
argument parsing, rectangle construction and the meanings of metadata.
All original field names, types, values, associations and precision remain.
Build from this directory as before; Make compiles the shared module first.
Keep the repository layout: the source is shared with future programs.

This is a writer-only extraction, following SGRAC's small unit-based routines.
It deliberately does not reuse SGRAC's triangle reader, which skips metadata.
Future readers must retain every input array, including unknown names, and
writers must carry them forward. Unsupported content must raise an error,
not silently disappear. Only explicit additions or updates are permitted.
The current source stage reads no input, so no round-trip reader is added yet.

Validation:
No execution environment was available for this refactor. Compile and compare
against the parent revision with:
  sh tests/compare_parent.sh
The check builds both versions separately and compares their entire stdout
byte-for-byte for square, rectangular and high-precision domains.

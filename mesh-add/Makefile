FC = gfortran
FFLAGS ?= -O2 -Wall -Wextra
FORPARSE_SRC ?= ../mesh-domain/vendor/forparse.f90
.PHONY: all clean test
all: mesh_add
build:
	mkdir -p build
build/forparse.o: $(FORPARSE_SRC) | build
	$(FC) $(FFLAGS) -Jbuild -Ibuild -c $< -o $@
build/vtk_io.o: ../src/vtk_io.f90 | build
	$(FC) $(FFLAGS) -Jbuild -Ibuild -c $< -o $@
build/fiberloc_geometry.o: ../src/fiberloc_geometry.f90 build/vtk_io.o | build
	$(FC) $(FFLAGS) -Jbuild -Ibuild -c $< -o $@
build/mesh_add.o: mesh_add.f90 build/forparse.o build/vtk_io.o build/fiberloc_geometry.o | build
	$(FC) $(FFLAGS) -Jbuild -Ibuild -c $< -o $@
mesh_add: build/forparse.o build/vtk_io.o build/fiberloc_geometry.o build/mesh_add.o
	$(FC) $(FFLAGS) $(LDFLAGS) -o $@ $^ $(LDLIBS)
test: mesh_add
	$(MAKE) -C ../mesh-domain
	python3 tests/check_pipeline.py
clean:
	rm -rf build mesh_add

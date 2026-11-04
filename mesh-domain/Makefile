FC = gfortran
FFLAGS ?= -O2 -Wall -Wextra
# Reuse your existing parser instead with FORPARSE_SRC=/path/to/forparse.f90.
FORPARSE_SRC ?= vendor/forparse.f90

.PHONY: all clean
all: mesh_domain
build:
	mkdir -p build
build/forparse.o: $(FORPARSE_SRC) | build
	$(FC) $(FFLAGS) -Jbuild -Ibuild -c $< -o $@
build/vtk_io.o: ../src/vtk_io.f90 | build
	$(FC) $(FFLAGS) -Jbuild -Ibuild -c $< -o $@
build/mesh_domain.o: mesh_domain.f90 build/forparse.o build/vtk_io.o | build
	$(FC) $(FFLAGS) -Jbuild -Ibuild -c $< -o $@
mesh_domain: build/forparse.o build/vtk_io.o build/mesh_domain.o
	$(FC) $(FFLAGS) $(LDFLAGS) -o $@ $^ $(LDLIBS)
clean:
	rm -rf build mesh_domain

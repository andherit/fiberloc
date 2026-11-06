FC = gfortran
FFLAGS ?= -O2 -Wall -Wextra
# Reuse your existing parser instead with FORPARSE_SRC=/path/to/forparse.f90.
FORPARSE_SRC ?= vendor/forparse.f90

# Shared executable directory. Use an absolute path when overriding BIN_DIR.
BIN_DIR ?= $(abspath ../bin)
TARGET := $(BIN_DIR)/mesh_domain

.PHONY: all clean mesh_domain
all: $(TARGET)
mesh_domain: $(TARGET)
build $(BIN_DIR):
	mkdir -p "$@"
build/forparse.o: $(FORPARSE_SRC) | build
	$(FC) $(FFLAGS) -Jbuild -Ibuild -c $< -o $@
build/vtk_io.o: ../src/vtk_io.f90 | build
	$(FC) $(FFLAGS) -Jbuild -Ibuild -c $< -o $@
build/mesh_domain.o: mesh_domain.f90 build/forparse.o build/vtk_io.o | build
	$(FC) $(FFLAGS) -Jbuild -Ibuild -c $< -o $@
$(TARGET): build/forparse.o build/vtk_io.o build/mesh_domain.o | $(BIN_DIR)
	$(FC) $(FFLAGS) $(LDFLAGS) -o $@ $^ $(LDLIBS)
clean:
	rm -rf build
	rm -f "$(TARGET)" mesh_domain

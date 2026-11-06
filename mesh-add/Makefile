FC = gfortran
FFLAGS ?= -O2 -Wall -Wextra
FORPARSE_SRC ?= ../mesh-domain/vendor/forparse.f90
# Shared executable directory. Use an absolute path when overriding BIN_DIR.
BIN_DIR ?= $(abspath ../bin)
TARGET := $(BIN_DIR)/mesh_add

.PHONY: all clean test mesh_add
all: $(TARGET)
mesh_add: $(TARGET)
build $(BIN_DIR):
	mkdir -p "$@"
build/forparse.o: $(FORPARSE_SRC) | build
	$(FC) $(FFLAGS) -Jbuild -Ibuild -c $< -o $@
build/vtk_io.o: ../src/vtk_io.f90 | build
	$(FC) $(FFLAGS) -Jbuild -Ibuild -c $< -o $@
build/fiberloc_geometry.o: ../src/fiberloc_geometry.f90 build/vtk_io.o | build
	$(FC) $(FFLAGS) -Jbuild -Ibuild -c $< -o $@
build/mesh_add.o: mesh_add.f90 build/forparse.o build/vtk_io.o build/fiberloc_geometry.o | build
	$(FC) $(FFLAGS) -Jbuild -Ibuild -c $< -o $@
$(TARGET): build/forparse.o build/vtk_io.o build/fiberloc_geometry.o build/mesh_add.o | $(BIN_DIR)
	$(FC) $(FFLAGS) $(LDFLAGS) -o $@ $^ $(LDLIBS)
test: mesh_add
	$(MAKE) -C ../mesh-domain BIN_DIR="$(BIN_DIR)"
	python3 tests/check_pipeline.py "$(BIN_DIR)"
clean:
	rm -rf build
	rm -f "$(TARGET)" mesh_add

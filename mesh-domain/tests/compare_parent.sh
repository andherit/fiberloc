#!/bin/sh
# Run from mesh-domain. Compare with the exact pre-refactor source revision.
# Uses temporary build directories; does not modify your build or checkout.
set -eu
root=$(git rev-parse --show-toplevel)
base=1ba603d5e11a0853477cffeff4edd20edd7f8619
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
mkdir -p "$tmp/old" "$tmp/new"
git -C "$root" show "$base:mesh-domain/mesh_domain.f90" > "$tmp/old/main.f90"
fc=${FC:-gfortran}
(cd "$tmp/old" && "$fc" -O0 -fcheck=all "$root/mesh-domain/vendor/forparse.f90" main.f90 -o mesh_domain)
(cd "$tmp/new" && "$fc" -O0 -fcheck=all "$root/mesh-domain/vendor/forparse.f90" \
 "$root/src/vtk_io.f90" "$root/mesh-domain/mesh_domain.f90" -o mesh_domain)
for args in 'lx=100 ly=100 sl=1.' 'lx=120 ly=80 sl=2.5' \
 'lx=1.234567890123456 ly=9.876543210987654 sl=0.0001'
do
 # Deliberately split these fixed, trusted argument lists into three words.
 "$tmp/old/mesh_domain" $args > "$tmp/old.vtk"
 "$tmp/new/mesh_domain" $args > "$tmp/new.vtk"
 cmp "$tmp/old.vtk" "$tmp/new.vtk"
done
printf '%s\n' 'PASS: complete VTK output unchanged in all three cases.'

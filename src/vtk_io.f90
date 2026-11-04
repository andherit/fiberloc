! Shared legacy ASCII VTK writers, extracted from mesh_domain.
! Uses SGRAC's unit-based, small-routine approach. No geometry-specific names.
! This first step is writer-only: no reader that could discard unknown arrays.
module vtk_io
   use, intrinsic :: iso_fortran_env, only : real64
   implicit none
   private
   public :: vtk_header, vtk_field_begin, vtk_field_int, vtk_field_real
   public :: vtk_points, vtk_lines, vtk_cell_data, vtk_scalar_int
contains
   subroutine vtk_header(unit,title)
      integer, intent(in) :: unit
      character(*), intent(in) :: title
      write(unit,'(a)') '# vtk DataFile Version 3.0'
      write(unit,'(a)') title
      write(unit,'(a)') 'ASCII'
      write(unit,'(a)') 'DATASET POLYDATA'
   end subroutine vtk_header

   subroutine vtk_field_begin(unit,count)
      integer, intent(in) :: unit,count
      ! Call before POINT_DATA/CELL_DATA for dataset-level metadata.
      write(unit,'(a,i0)') 'FIELD FieldData ',count
   end subroutine vtk_field_begin

   subroutine vtk_field_int(unit,name,values)
      integer, intent(in) :: unit,values(:,:)
      character(*), intent(in) :: name
      integer :: j
      ! Layout: values(component,tuple). Names and all components are retained.
      write(unit,'(a,1x,i0,1x,i0,a)') trim(name),size(values,1),size(values,2),' int'
      do j=1,size(values,2)
         write(unit,'(*(i0,:,1x))') values(:,j)
      enddo
   end subroutine vtk_field_int

   subroutine vtk_field_real(unit,name,values)
      integer, intent(in) :: unit
      character(*), intent(in) :: name
      real(real64), intent(in) :: values(:,:)
      integer :: j
      write(unit,'(a,1x,i0,1x,i0,a)') trim(name),size(values,1),size(values,2),' double'
      do j=1,size(values,2)
         ! Keep the original mesh_domain precision and formatting.
         if (size(values,1) == 1) then
            write(unit,'(es24.16e3)') values(1,j)
         else
            write(unit,'(*(es24.16e3,1x))') values(:,j)
         endif
      enddo
   end subroutine vtk_field_real

   subroutine vtk_points(unit,xyz)
      integer, intent(in) :: unit
      real(real64), intent(in) :: xyz(:,:)
      integer :: j
      if (size(xyz,1) /= 3) error stop 'vtk_points: expected xyz(3,n)'
      write(unit,'(a,i0,a)') 'POINTS ',size(xyz,2),' double'
      do j=1,size(xyz,2)
         write(unit,'(3(es24.16e3,1x))') xyz(:,j)
      enddo
   end subroutine vtk_points

   subroutine vtk_lines(unit,ends)
      integer, intent(in) :: unit,ends(:,:)
      integer :: j
      ! Two-node segments. Input indices are already zero-based VTK IDs.
      ! Do not renumber here: geometry construction owns connectivity.
      if (size(ends,1) /= 2) error stop 'vtk_lines: expected ends(2,n)'
      if (any(ends < 0)) error stop 'vtk_lines: negative point ID'
      write(unit,'(a,i0,1x,i0)') 'LINES ',size(ends,2),3*size(ends,2)
      do j=1,size(ends,2)
         write(unit,'(i0,2(1x,i0))') 2,ends(:,j)
      enddo
   end subroutine vtk_lines

   subroutine vtk_cell_data(unit,count)
      integer, intent(in) :: unit,count
      ! Count includes all cells, in VTK order: vertices, lines, polygons.
      write(unit,'(a,i0)') 'CELL_DATA ',count
   end subroutine vtk_cell_data

   subroutine vtk_scalar_int(unit,name,values)
      integer, intent(in) :: unit,values(:)
      character(*), intent(in) :: name
      ! Association is set by the preceding POINT_DATA or CELL_DATA header.
      write(unit,'(a,a,a)') 'SCALARS ',trim(name),' int 1'
      write(unit,'(a)') 'LOOKUP_TABLE default'
      write(unit,'(*(i0,:,1x))') values
   end subroutine vtk_scalar_int
end module vtk_io

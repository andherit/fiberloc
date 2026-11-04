! First geometry-pipeline stage. No meshing or Gmsh dependency here.
! Example: ./mesh_domain lx=100 ly=100 sl=1. > domain.vtk
program mesh_domain
   use, intrinsic :: iso_fortran_env, only : real64, output_unit, error_unit
   use, intrinsic :: ieee_arithmetic, only : ieee_is_finite
   use forparse, only : parse_arg, PARSE_OK
   implicit none

   real(real64) :: lx, ly, sl
   integer :: i, n, eq, arg_length, key_index
   logical :: seen(3)
   character(len=100) :: arg

   ! forparse uses a 100-character argument buffer. Check the command shape
   ! before calling it, so truncated, duplicate or misspelled options cannot
   ! silently change the geometry. Value extraction remains in forparse.
   n = command_argument_count()
   if (n == 0) then
      call usage()
      stop 1
   endif
   if (n == 1) then
      call get_command_argument(1,arg)
      if (trim(arg) == '--help' .or. trim(arg) == '-h') then
         call usage()
         stop
      endif
   endif
   seen = .false.
   do i = 1,n
      call get_command_argument(i,length=arg_length)
      if (arg_length > len(arg)) call fail('Argument exceeds forparse buffer (100 characters).')
      call get_command_argument(i,arg)
      eq = index(arg,'=')
      if (eq <= 1 .or. eq == len_trim(arg)) call fail('Expected key=value: '//trim(arg))
      select case(arg(:eq-1))
      case('lx')
         key_index = 1
      case('ly')
         key_index = 2
      case('sl')
         key_index = 3
      case default
         call fail('Unknown argument: '//trim(arg))
      end select
      if (seen(key_index)) call fail('Duplicate argument: '//arg(:eq-1))
      seen(key_index) = .true.
   enddo

   call positive_real('lx',lx)
   call positive_real('ly',ly)
   call positive_real('sl',sl)

   ! All arguments are validated before writing anything to stdout.
   ! FIELD precedes geometry: these are dataset-level attributes, not values
   ! attached to boundary points or cells. Bounds use the VTK ordering
   ! xmin,xmax,ymin,ymax,zmin,zmax; all lengths share the same user-chosen unit.
   write(output_unit,'(a)') '# vtk DataFile Version 3.0'
   write(output_unit,'(a)') 'mesh_domain: rectangular planar geometry'
   write(output_unit,'(a)') 'ASCII'
   write(output_unit,'(a)') 'DATASET POLYDATA'
   write(output_unit,'(a)') 'FIELD FieldData 3'
   write(output_unit,'(a)') 'schema_version 1 1 int'
   write(output_unit,'(i0)') 1
   write(output_unit,'(a)') 'domain_bounds 6 1 double'
   write(output_unit,'(6(es24.16e3,1x))') 0._real64,lx,0._real64,ly,0._real64,0._real64
   write(output_unit,'(a)') 'mesh_size 1 1 double'
   write(output_unit,'(es24.16e3)') sl

   ! Four corners and four boundary edges, counterclockwise in the XY plane.
   ! VTK connectivity is zero-based. LINES size = 4 * (2 node IDs + 1 count).
   ! No triangles are generated; sl is a target size for mesh_generate later.
   write(output_unit,'(a)') 'POINTS 4 double'
   write(output_unit,'(3(es24.16e3,1x))') 0._real64,0._real64,0._real64
   write(output_unit,'(3(es24.16e3,1x))') lx,0._real64,0._real64
   write(output_unit,'(3(es24.16e3,1x))') lx,ly,0._real64
   write(output_unit,'(3(es24.16e3,1x))') 0._real64,ly,0._real64
   write(output_unit,'(a)') 'LINES 4 12'
   write(output_unit,'(a)') '2 0 1','2 1 2','2 2 3','2 3 0'

   ! Readable integer flags avoid string encodings or opaque role codes.
   ! Future mesh_add must preserve these arrays, assigning 0 to non-boundary
   ! cells. sensor_id=0 means this primitive is not a sensing instrument.
   write(output_unit,'(a)') 'CELL_DATA 4'
   write(output_unit,'(a)') 'SCALARS is_domain_boundary int 1'
   write(output_unit,'(a)') 'LOOKUP_TABLE default'
   write(output_unit,'(a)') '1 1 1 1'
   write(output_unit,'(a)') 'SCALARS sensor_id int 1'
   write(output_unit,'(a)') 'LOOKUP_TABLE default'
   write(output_unit,'(a)') '0 0 0 0'
   flush(output_unit)

contains

   subroutine positive_real(key,value)
      character(len=*), intent(in) :: key
      real(real64), intent(out) :: value
      character(len=100) :: token
      integer :: status, j
      ! SGRAC's parse_arg(real) accepts default REAL only. Reuse its string
      ! overload and convert directly to real64 to avoid rounding via real32.
      status = parse_arg(key,token)
      if (status /= PARSE_OK) call fail('Missing required argument: '//key)
      token = trim(adjustl(token))
      ! Reject list-directed separators, null values and trailing tokens.
      ! E/e and D/d exponent notation are both supported.
      if (len_trim(token) == 0) call fail('Empty value for '//key)
      do j = 1,len_trim(token)
         if (index('0123456789+-.eEdD',token(j:j)) == 0) call fail('Invalid number for '//key)
      enddo
      read(token,*,iostat=status) value
      if (status /= 0) call fail('Invalid number for '//key)
      if (.not. ieee_is_finite(value)) call fail('Non-finite value for '//key)
      if (value <= 0._real64) call fail(key//' must be positive.')
   end subroutine positive_real

   subroutine usage()
      ! Help and failures use stderr; stdout is reserved for valid VTK data.
      write(error_unit,'(a)') 'Usage: mesh_domain lx=100 ly=100 sl=1. > domain.vtk'
      write(error_unit,'(a)') 'lx, ly: positive domain lengths; sl: positive target mesh size.'
      write(error_unit,'(a)') 'Domain origin is (0,0,0); geometry lies in the XY plane.'
   end subroutine usage

   subroutine fail(message)
      character(len=*), intent(in) :: message
      write(error_unit,'(a)') 'mesh_domain: '//message
      stop 1
   end subroutine fail
end program mesh_domain

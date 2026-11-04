! First geometry-pipeline stage. No meshing or Gmsh dependency here.
! Example: ./mesh_domain lx=100 ly=100 sl=1. > domain.vtk
program mesh_domain
   use, intrinsic :: iso_fortran_env, only : real64, output_unit, error_unit
   use, intrinsic :: ieee_arithmetic, only : ieee_is_finite
   use forparse, only : parse_arg, PARSE_OK
   use vtk_io, only : vtk_header, vtk_field_begin, vtk_field_int, vtk_field_real, &
      vtk_points, vtk_lines, vtk_cell_data, vtk_scalar_int
   implicit none

   real(real64) :: lx, ly, sl
   real(real64) :: xyz(3,4), bounds(6)
   integer :: edges(2,4)
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

   ! Geometry and field meanings belong here; VTK serialization belongs in
   ! the shared module. All current fields are retained in their original order.
   bounds = [0._real64,lx,0._real64,ly,0._real64,0._real64]
   xyz(:,1) = [0._real64,0._real64,0._real64]
   xyz(:,2) = [lx,0._real64,0._real64]
   xyz(:,3) = [lx,ly,0._real64]
   xyz(:,4) = [0._real64,ly,0._real64]
   ! Counterclockwise edges, using zero-based VTK point IDs.
   edges = reshape([0,1, 1,2, 2,3, 3,0],[2,4])

   call vtk_header(output_unit,'mesh_domain: rectangular planar geometry')
   call vtk_field_begin(output_unit,3)
   call vtk_field_int(output_unit,'schema_version',reshape([1],[1,1]))
   call vtk_field_real(output_unit,'domain_bounds',reshape(bounds,[6,1]))
   call vtk_field_real(output_unit,'mesh_size',reshape([sl],[1,1]))
   call vtk_points(output_unit,xyz)
   call vtk_lines(output_unit,edges)
   call vtk_cell_data(output_unit,4)
   call vtk_scalar_int(output_unit,'is_domain_boundary',[1,1,1,1])
   call vtk_scalar_int(output_unit,'sensor_id',[0,0,0,0])
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

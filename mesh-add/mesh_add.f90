! Add exactly one primitive to the geometry stream. All parsing and geometry
! checks finish before any stdout output, so failures cannot emit partial VTK.
program mesh_add
   use, intrinsic :: iso_fortran_env, only : real64,input_unit,output_unit,error_unit
   use forparse, only : parse_arg,PARSE_OK
   use vtk_io
   use fiberloc_geometry, only : add_primitive
   implicit none
   type(vtk_document) :: d
   real(real64) :: xyz(3,2)
   character(100) :: arg,primitive,value
   character(10), parameter :: keys(9)=[character(10)::'primitive','id','x','y','z','x1','y1','x2','y2']
   logical :: seen(9)
   integer :: i,j,eq,n,status,sensor,length
   seen=.false.; xyz=0._real64; sensor=0
   n=command_argument_count()
   if(n==0) then
      call help(); stop 1
   endif
   if(n==1) then
      call get_command_argument(1,arg)
      if(trim(arg)=='--help' .or. trim(arg)=='-h') then
         call help(); stop
      endif
   endif
   do i=1,n
      call get_command_argument(i,length=length)
      if(length>100) call vtk_die('Argument exceeds forparse buffer')
      call get_command_argument(i,arg)
      eq=index(arg,'=')
      if(eq<=1 .or. eq==len_trim(arg)) call vtk_die('Expected key=value')
      j=1
      do while(j<=size(keys))
         if(arg(:eq-1)==trim(keys(j))) exit
         j=j+1
      enddo
      if(j>size(keys)) call vtk_die('Unknown argument: '//arg(:eq-1))
      if(seen(j)) call vtk_die('Duplicate argument: '//arg(:eq-1))
      seen(j)=.true.
   enddo
   status=parse_arg('primitive',primitive)
   if(status/=PARSE_OK) call vtk_die('Missing primitive=point|line')
   if(seen(2)) then
      status=parse_arg('id',value)
      if(status/=PARSE_OK) call vtk_die('Invalid id')
      sensor=vtk_integer(trim(value))
   endif
   select case(trim(primitive))
   case('point')
      if(any(seen(6:9))) call vtk_die('Point uses x,y,z, not x1,y1,x2,y2')
      xyz(1,1)=number('x'); xyz(2,1)=number('y')
      if(seen(5)) xyz(3,1)=number('z')
   case('line')
      if(any(seen(3:5))) call vtk_die('Planar line uses x1,y1,x2,y2')
      if(.not.seen(2)) call vtk_die('Line requires id=<positive integer>')
      xyz(1,1)=number('x1'); xyz(2,1)=number('y1')
      xyz(1,2)=number('x2'); xyz(2,2)=number('y2')
   case default
      call vtk_die('Unknown primitive: '//trim(primitive))
   end select
   call vtk_read(input_unit,d)
   if(trim(primitive)=='point') then
      call add_primitive(d,'point',xyz(:,:1),sensor)
   else
      call add_primitive(d,'line',xyz,sensor)
   endif
   call vtk_write(output_unit,d)
contains
   function number(key) result(v)
      character(*), intent(in) :: key
      real(real64) :: v
      character(100) :: token
      integer :: ios
      ! Reuse forparse string overload; avoid conversion through default REAL.
      ios=parse_arg(key,token)
      if(ios/=PARSE_OK) call vtk_die('Missing coordinate: '//key)
      v=vtk_real(trim(adjustl(token)))
   end function
   subroutine help()
      write(error_unit,'(a)') 'mesh_add primitive=point x=50 y=50 [z=0] [id=0] < domain.vtk > points.vtk'
      write(error_unit,'(a)') 'mesh_add primitive=line id=1 x1=0 y1=60 x2=80 y2=100 < points.vtk > cables.vtk'
      write(error_unit,'(a)') 'id=0: geometric point; positive IDs: sensors, unique across points and lines.'
   end subroutine
end program mesh_add

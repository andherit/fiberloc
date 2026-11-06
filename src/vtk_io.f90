! Shared legacy ASCII VTK writers, extracted from mesh_domain.
! Uses SGRAC's unit-based, small-routine approach. No geometry-specific names.
! Numeric arrays retain their original tokens: unknown metadata is never discarded.
module vtk_io
   use, intrinsic :: iso_fortran_env, only : real64, error_unit, iostat_end, iostat_eor
   implicit none
   private
   public :: vtk_header, vtk_field_begin, vtk_field_int, vtk_field_real
   public :: vtk_points, vtk_lines, vtk_cell_data, vtk_scalar_int
   public :: vtk_document, vtk_read, vtk_write, vtk_token, vtk_array
   public :: vtk_die, vtk_integer, vtk_real, vtk_pack_real
   type :: vtk_token
      character(:), allocatable :: text
   end type
   type :: vtk_array
      character(:), allocatable :: name, dtype, form, group
      integer :: association=0, components=1, tuples=0
      type(vtk_token), allocatable :: values(:)
   end type
   type :: vtk_document
      character(:), allocatable :: title, point_type
      type(vtk_token), allocatable :: points(:)
      ! Packed VTK connectivity: count followed by zero-based point IDs.
      integer, allocatable :: vertices(:), lines(:), polygons(:)
      integer :: nv=0, nl=0, np=0
      type(vtk_array), allocatable :: arrays(:)
   end type
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


   subroutine vtk_die(message)
      character(*), intent(in) :: message
      write(error_unit,'(a)') 'vtk_io: '//message
      stop 1
   end subroutine

   integer function vtk_integer(t) result(v)
      character(*), intent(in) :: t
      integer :: ios,j
      if (len(t)==0) call vtk_die('Empty integer')
      do j=1,len(t)
         if (index('0123456789+-',t(j:j))==0) call vtk_die('Invalid integer: '//t)
      enddo
      read(t,*,iostat=ios) v
      if (ios/=0) call vtk_die('Invalid integer: '//t)
   end function

   real(real64) function vtk_real(t) result(v)
      character(*), intent(in) :: t
      integer :: ios,j
      do j=1,len(t)
         if (index('0123456789+-.eEdD',t(j:j))==0) call vtk_die('Invalid real: '//t)
      enddo
      read(t,*,iostat=ios) v
      if (ios/=0) call vtk_die('Invalid real: '//t)
   end function

   function vtk_pack_real(v) result(t)
      real(real64), intent(in) :: v
      type(vtk_token) :: t
      character(32) :: buffer
      write(buffer,'(es24.16e3)') v
      t%text=trim(adjustl(buffer))
   end function

   ! Read arbitrary-length formatted records from files or pipes; never rewind.
   subroutine read_record(unit,line,ios)
      integer, intent(in) :: unit
      character(:), allocatable, intent(out) :: line
      integer, intent(out) :: ios
      character(1024) :: chunk
      integer :: count
      line=''
      do
         read(unit,'(a)',advance='no',size=count,iostat=ios) chunk
         if (count>0) line=line//chunk(:count)
         if (ios==iostat_eor) then
            ios=0
            return
         endif
         if (ios/=0) return
      enddo
   end subroutine

   subroutine tokenize(line,tokens)
      character(*), intent(in) :: line
      type(vtk_token), allocatable, intent(out) :: tokens(:)
      integer :: i,j,n,k
      ! Two passes avoid quadratic array growth for long numeric records.
      n=0; i=1
      do while(i<=len(line))
         if (line(i:i)==' ' .or. line(i:i)==achar(9) .or. line(i:i)==achar(13)) then
            i=i+1
         else
            n=n+1
            do while(i<=len(line))
               if (index(' '//achar(9)//achar(13),line(i:i))/=0) exit
               i=i+1
            enddo
         endif
      enddo
      allocate(tokens(n)); i=1; k=0
      do while(i<=len(line))
         if (index(' '//achar(9)//achar(13),line(i:i))/=0) then
            i=i+1
         else
            j=i
            do while(i<=len(line))
               if (index(' '//achar(9)//achar(13),line(i:i))/=0) exit
               i=i+1
            enddo
            k=k+1; tokens(k)%text=line(j:i-1)
         endif
      enddo
   end subroutine

   subroutine next_record(unit,t,ios)
      integer, intent(in) :: unit
      type(vtk_token), allocatable, intent(out) :: t(:)
      integer, intent(out) :: ios
      character(:), allocatable :: line
      do
         call read_record(unit,line,ios)
         if (ios/=0) then
            allocate(t(0)); return
         endif
         call tokenize(line,t)
         if (size(t)>0) return
         deallocate(t)
      enddo
   end subroutine

   subroutine read_values(unit,n,values)
      integer, intent(in) :: unit,n
      type(vtk_token), allocatable, intent(out) :: values(:)
      type(vtk_token), allocatable :: row(:)
      integer :: k,ios,m
      if(n<0) call vtk_die('Negative array length')
      allocate(values(n)); k=0
      do while(k<n)
         call next_record(unit,row,ios)
         if(ios/=0) call vtk_die('Truncated numeric array')
         m=size(row)
         if(m>n-k) call vtk_die('Too many values in numeric array')
         values(k+1:k+m)=row; k=k+m
      enddo
   end subroutine

   subroutine check_values(a)
      type(vtk_array), intent(in) :: a
      integer :: j,iv
      real(real64) :: rv
      ! Only types that this implementation can validate without narrowing.
      ! Lexical storage preserves integer precision and double representations.
      select case(a%dtype)
      case('int','short','unsigned_short','char','unsigned_char')
         do j=1,size(a%values)
            iv=vtk_integer(a%values(j)%text)
         enddo
      case('float','double')
         do j=1,size(a%values)
            rv=vtk_real(a%values(j)%text)
         enddo
      case default
         call vtk_die('Unsupported numeric type (not discarded): '//a%dtype)
      end select
   end subroutine

   subroutine read_cells(unit,n,total,packed)
      integer, intent(in) :: unit,n,total
      integer, allocatable, intent(out) :: packed(:)
      type(vtk_token), allocatable :: values(:)
      integer :: j,k,m
      call read_values(unit,total,values)
      allocate(packed(total))
      do j=1,total
         packed(j)=vtk_integer(values(j)%text)
      enddo
      k=1
      do j=1,n
         if(k>total) call vtk_die('Truncated connectivity')
         m=packed(k)
         if(m<1 .or. m>total-k) call vtk_die('Invalid cell size')
         k=k+m+1
      enddo
      if(k/=total+1) call vtk_die('Connectivity count mismatch')
   end subroutine

   subroutine vtk_read(unit,d)
      integer, intent(in) :: unit
      type(vtk_document), intent(out) :: d
      type(vtk_token), allocatable :: t(:)
      type(vtk_array) :: a
      character(:), allocatable :: line,group
      integer :: ios,assoc,nt,n,j,k,points_count,seen_assoc(2)
      logical :: have_points, have_v,have_l,have_p
      call read_record(unit,line,ios)
      if(ios/=0) call vtk_die('Missing VTK header')
      if(trim(line)/='# vtk DataFile Version 3.0') call vtk_die('Expected legacy VTK version 3.0')
      call read_record(unit,d%title,ios)
      if(ios/=0) call vtk_die('Missing title')
      call read_record(unit,line,ios)
      if(ios/=0 .or. trim(line)/='ASCII') call vtk_die('Only ASCII supported')
      call read_record(unit,line,ios)
      if(ios/=0 .or. trim(line)/='DATASET POLYDATA') call vtk_die('Only POLYDATA supported')
      allocate(d%arrays(0),d%vertices(0),d%lines(0),d%polygons(0))
      assoc=0; nt=0; points_count=0; seen_assoc=0
      have_points=.false.; have_v=.false.; have_l=.false.; have_p=.false.
      do
         call next_record(unit,t,ios)
         if(ios==iostat_end) exit
         if(ios/=0) call vtk_die('Input read error')
         select case(t(1)%text)
         case('POINTS')
            if(size(t)/=3 .or. have_points .or. assoc/=0) call vtk_die('Invalid POINTS header')
            points_count=vtk_integer(t(2)%text)
            if(points_count<0 .or. points_count>huge(n)/3) call vtk_die('Invalid point count')
            d%point_type=t(3)%text
            if(d%point_type/='float' .and. d%point_type/='double') call vtk_die('Unsupported POINTS type')
            call read_values(unit,3*points_count,d%points)
            do j=1,size(d%points)
               block
                  real(real64) :: v
                  v=vtk_real(d%points(j)%text)
               end block
            enddo
            have_points=.true.
         case('VERTICES','LINES','POLYGONS')
            if(size(t)/=3 .or. assoc/=0) call vtk_die('Invalid geometry header')
            n=vtk_integer(t(2)%text); k=vtk_integer(t(3)%text)
            if(n<0 .or. k<0) call vtk_die('Negative connectivity count')
            select case(t(1)%text)
            case('VERTICES')
               if(have_v) call vtk_die('Duplicate VERTICES')
               call read_cells(unit,n,k,d%vertices); d%nv=n; have_v=.true.
            case('LINES')
               if(have_l) call vtk_die('Duplicate LINES')
               call read_cells(unit,n,k,d%lines); d%nl=n; have_l=.true.
            case('POLYGONS')
               if(have_p) call vtk_die('Duplicate POLYGONS')
               call read_cells(unit,n,k,d%polygons); d%np=n; have_p=.true.
            end select
         case('POINT_DATA','CELL_DATA')
            if(size(t)/=2) call vtk_die('Invalid attribute association')
            assoc=1
            if(t(1)%text=='CELL_DATA') assoc=2
            if(seen_assoc(assoc)/=0) call vtk_die('Duplicate attribute association')
            seen_assoc(assoc)=1
            nt=vtk_integer(t(2)%text)
            if(assoc==1 .and. nt/=points_count) call vtk_die('POINT_DATA count mismatch')
            if(assoc==2 .and. nt/=d%nv+d%nl+d%np) call vtk_die('CELL_DATA count mismatch')
         case('FIELD')
            if(size(t)/=3) call vtk_die('Invalid FIELD header')
            group=t(2)%text; n=vtk_integer(t(3)%text)
            if(n<0) call vtk_die('Negative FIELD count')
            do j=1,n
               call next_record(unit,t,ios)
               if(ios/=0 .or. size(t)/=4) call vtk_die('Invalid FIELD array header')
               a%name=t(1)%text; a%components=vtk_integer(t(2)%text)
               a%tuples=vtk_integer(t(3)%text); a%dtype=t(4)%text
               a%form='FIELD'; a%group=group; a%association=assoc
               call read_array()
            enddo
         case('SCALARS','VECTORS','NORMALS','TENSORS')
            if(assoc==0 .or. size(t)<3) call vtk_die('Attribute without association')
            a%form=t(1)%text; a%name=t(2)%text; a%dtype=t(3)%text
            a%group=''; a%association=assoc; a%tuples=nt; a%components=3
            if(a%form=='TENSORS') a%components=9
            if(a%form=='SCALARS') then
               a%components=1
               if(size(t)==4) a%components=vtk_integer(t(4)%text)
               if(size(t)>4) call vtk_die('Invalid SCALARS header')
               call next_record(unit,t,ios)
               if(ios/=0 .or. size(t)/=2) call vtk_die('Missing LOOKUP_TABLE')
               if(t(1)%text/='LOOKUP_TABLE' .or. t(2)%text/='default') &
                  call vtk_die('Only default lookup table supported')
            else
               if(size(t)/=3) call vtk_die('Invalid vector/tensor header')
            endif
            call read_array()
         case default
            call vtk_die('Unsupported section (not discarded): '//t(1)%text)
         end select
      enddo
      if(.not.have_points) call vtk_die('Missing POINTS')
      call check_indices(d%vertices); call check_indices(d%lines); call check_indices(d%polygons)
   contains
      subroutine read_array()
         integer :: q
         if(a%components<1 .or. a%tuples<0) call vtk_die('Invalid array shape')
         if(a%tuples>huge(n)/a%components) call vtk_die('Array size overflow')
         do q=1,size(d%arrays)
            if(d%arrays(q)%association==a%association .and. d%arrays(q)%name==a%name) &
               call vtk_die('Duplicate array name: '//a%name)
         enddo
         call read_values(unit,a%components*a%tuples,a%values)
         call check_values(a)
         d%arrays=[d%arrays,a]
      end subroutine
      subroutine check_indices(packed)
         integer, intent(in) :: packed(:)
         integer :: q,m
         q=1
         do while(q<=size(packed))
            m=packed(q)
            if(any(packed(q+1:q+m)<0) .or. any(packed(q+1:q+m)>=points_count)) &
               call vtk_die('Connectivity references missing point')
            q=q+m+1
         enddo
      end subroutine
   end subroutine vtk_read

   subroutine vtk_write(unit,d)
      integer, intent(in) :: unit
      type(vtk_document), intent(in) :: d
      integer :: assoc,j,k
      call vtk_header(unit,d%title)
      call arrays(0)
      write(unit,'(a,i0,1x,a)') 'POINTS ',size(d%points)/3,d%point_type
      do j=1,size(d%points),3
         write(unit,'(a,1x,a,1x,a)') d%points(j)%text,d%points(j+1)%text,d%points(j+2)%text
      enddo
      call cells('VERTICES',d%nv,d%vertices)
      call cells('LINES',d%nl,d%lines)
      call cells('POLYGONS',d%np,d%polygons)
      do assoc=1,2
         if(.not.any(d%arrays%association==assoc)) cycle
         if(assoc==1) write(unit,'(a,i0)') 'POINT_DATA ',size(d%points)/3
         if(assoc==2) write(unit,'(a,i0)') 'CELL_DATA ',d%nv+d%nl+d%np
         call arrays(assoc)
      enddo
      flush(unit)
   contains
      subroutine cells(name,n,packed)
         character(*), intent(in) :: name
         integer, intent(in) :: n,packed(:)
         integer :: q,m
         if(n==0) return
         write(unit,'(a,1x,i0,1x,i0)') name,n,size(packed)
         q=1
         do while(q<=size(packed))
            m=packed(q)
            write(unit,'(*(i0,:,1x))') packed(q:q+m)
            q=q+m+1
         enddo
      end subroutine
      subroutine arrays(which)
         integer, intent(in) :: which
         integer :: q,r,count
         logical :: already
         ! One block per FIELD group: some VTK readers replace an earlier block
         ! with the same name, so repeated one-array blocks would lose metadata.
         do k=1,size(d%arrays)
            if(d%arrays(k)%association/=which) cycle
            associate(a=>d%arrays(k))
               if(a%form=='FIELD') then
                  already=.false.; count=0
                  do q=1,size(d%arrays)
                     if(d%arrays(q)%association/=which .or. d%arrays(q)%form/='FIELD') cycle
                     if(d%arrays(q)%group/=a%group) cycle
                     if(q<k) already=.true.
                     count=count+1
                  enddo
                  if(already) cycle
                  write(unit,'(a,a,1x,i0)') 'FIELD ',a%group,count
                  do q=k,size(d%arrays)
                     if(d%arrays(q)%association/=which .or. d%arrays(q)%form/='FIELD') cycle
                     if(d%arrays(q)%group/=a%group) cycle
                     associate(f=>d%arrays(q))
                        write(unit,'(a,1x,i0,1x,i0,1x,a)') f%name,f%components,f%tuples,f%dtype
                        do r=1,size(f%values)
                           write(unit,'(a)') f%values(r)%text
                        enddo
                     end associate
                  enddo
               else
                  if(a%form=='SCALARS') then
                     write(unit,'(a,a,1x,a,1x,i0)') 'SCALARS ',a%name,a%dtype,a%components
                     write(unit,'(a)') 'LOOKUP_TABLE default'
                  else
                     write(unit,'(a,1x,a,1x,a)') a%form,a%name,a%dtype
                  endif
                  do j=1,size(a%values)
                     write(unit,'(a)') a%values(j)%text
                  enddo
               endif
            end associate
         enddo
      end subroutine
   end subroutine vtk_write
end module vtk_io

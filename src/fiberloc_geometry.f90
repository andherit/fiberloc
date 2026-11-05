! Geometry edits operate on vtk_document; serialization stays in vtk_io.
module fiberloc_geometry
   use, intrinsic :: iso_fortran_env, only : real64
   use, intrinsic :: ieee_arithmetic, only : ieee_is_finite
   use vtk_io
   implicit none
   private
   public :: add_primitive
contains
   subroutine add_primitive(d,primitive,xyz,sensor)
      type(vtk_document), intent(inout) :: d
      character(*), intent(in) :: primitive
      real(real64), intent(in) :: xyz(:,:)
      integer, intent(in) :: sensor
      integer :: i,j,k,nold,nnew,ncells,insertion,boundary_index,sensor_index,bounds_index,ids(2)
      real(real64) :: bounds(6),oldxyz(3)
      type(vtk_token), allocatable :: extra(:)
      logical :: is_point
      is_point=primitive=='point'
      if(.not.is_point .and. primitive/='line') call vtk_die('Unknown primitive')
      nnew=2
      if(is_point) nnew=1
      if(size(xyz,1)/=3 .or. size(xyz,2)/=nnew) call vtk_die('Primitive shape mismatch')
      if(.not.all(ieee_is_finite(xyz))) call vtk_die('Non-finite primitive coordinate')
      if(sensor<0) call vtk_die('Negative sensor ID')
      if(.not.is_point .and. sensor==0) call vtk_die('Line requires positive sensor ID')
      if(.not.is_point) then
         if(all(xyz(:,1)==xyz(:,2))) call vtk_die('Zero-length line')
      endif
      nold=size(d%points)/3; ncells=d%nv+d%nl+d%np
      boundary_index=0; sensor_index=0; bounds_index=0
      do i=1,size(d%arrays)
         associate(a=>d%arrays(i))
            if(a%association==0 .and. a%name=='domain_bounds') bounds_index=i
            if(a%association==2 .and. a%name=='is_domain_boundary') boundary_index=i
            if(a%association==2 .and. a%name=='sensor_id') sensor_index=i
         end associate
      enddo
      if(bounds_index==0 .or. boundary_index==0 .or. sensor_index==0) &
         call vtk_die('Required domain metadata/attributes missing')
      if(size(d%arrays(bounds_index)%values)/=6) call vtk_die('Expected six domain bounds')
      do i=1,6
         bounds(i)=vtk_real(d%arrays(bounds_index)%values(i)%text)
      enddo
      if(.not.all(ieee_is_finite(bounds))) call vtk_die('Non-finite domain bounds')
      if(any(bounds([2,4,6])<bounds([1,3,5]))) call vtk_die('Invalid domain bounds')
      do j=1,nnew
         if(any(xyz(:,j)<bounds([1,3,5])) .or. any(xyz(:,j)>bounds([2,4,6]))) &
            call vtk_die('Primitive outside domain bounds')
      enddo
      ! A positive sensor ID identifies one point or one cable. ID 0 is a
      ! geometric constraint only (e.g. the fixed centre), not a sensor.
      associate(a=>d%arrays(sensor_index))
         if(a%dtype/='int' .or. a%components/=1 .or. a%tuples/=ncells) &
            call vtk_die('Invalid sensor_id array')
         do j=1,size(a%values)
            if(sensor>0 .and. vtk_integer(a%values(j)%text)==sensor) call vtk_die('Sensor ID already used')
         enddo
      end associate
      associate(a=>d%arrays(boundary_index))
         if(a%dtype/='int' .or. a%components/=1 .or. a%tuples/=ncells) &
            call vtk_die('Invalid is_domain_boundary array')
      end associate

      ! Reuse exactly coincident coordinates. No tolerance-based merging that
      ! could move a point or silently remove a small geometric feature.
      allocate(extra(0))
      do j=1,nnew
         ids(j)=-1
         do i=1,nold
            do k=1,3
               oldxyz(k)=vtk_real(d%points(3*(i-1)+k)%text)
            enddo
            if(all(oldxyz==xyz(:,j))) then
               ids(j)=i-1; exit
            endif
         enddo
         if(ids(j)<0) then
            ids(j)=nold+size(extra)/3
            do k=1,3
               extra=[extra,vtk_pack_real(xyz(k,j))]
            enddo
         endif
      enddo
      if(is_point) then
         k=1
         do i=1,d%nv
            if(d%vertices(k)==1) then
               if(d%vertices(k+1)==ids(1)) call vtk_die('Point primitive already exists at these coordinates')
            endif
            k=k+d%vertices(k)+1
         enddo
      else
         k=1
         do i=1,d%nl
            if(d%lines(k)==2) then
               if(all(d%lines(k+1:k+2)==ids) .or. all(d%lines(k+1:k+2)==ids(2:1:-1))) &
                  call vtk_die('Line primitive already exists')
            endif
            k=k+d%lines(k)+1
         enddo
      endif

      ! There is no scientifically valid default for arbitrary measurements on
      ! a new point/cell. Preserve dataset metadata, but refuse an edit needing
      ! undefined attribute values. Never drop an unknown array or pad silently.
      do i=1,size(d%arrays)
         associate(a=>d%arrays(i))
            if(a%association==1 .and. size(extra)>0) &
               call vtk_die('Cannot assign new point values for array: '//a%name)
            if(a%association==2 .and. i/=boundary_index .and. i/=sensor_index) &
               call vtk_die('Cannot assign new cell values for array: '//a%name)
         end associate
      enddo
      ! VTK cell order is VERTICES, LINES, POLYGONS. Inserting a vertex must
      ! shift existing line/polygon attributes, rather than append blindly.
      insertion=d%nv
      if(.not.is_point) insertion=d%nv+d%nl
      call insert_value(d%arrays(boundary_index),insertion,0)
      call insert_value(d%arrays(sensor_index),insertion,sensor)
      d%points=[d%points,extra]
      ! New coordinates are double precision; preserve existing tokens while
      ! promoting a float geometry so new coordinates are not narrowed.
      if(size(extra)>0) d%point_type='double'
      if(is_point) then
         d%vertices=[d%vertices,1,ids(1)]; d%nv=d%nv+1
      else
         d%lines=[d%lines,2,ids]; d%nl=d%nl+1
      endif
   end subroutine

   subroutine insert_value(a,position,value)
      type(vtk_array), intent(inout) :: a
      integer, intent(in) :: position,value
      type(vtk_token) :: t
      character(32) :: buffer
      write(buffer,'(i0)') value
      t%text=trim(buffer)
      a%values=[a%values(:position),t,a%values(position+1:)]
      a%tuples=a%tuples+1
   end subroutine
end module fiberloc_geometry

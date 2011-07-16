program cgns_coarsen

  !use cgnsGrid

  implicit none
  include 'cgnslib_f.h'

  integer  CellDim, PhysDim
  integer nbases, nzones, in_dims(9),out_dims(9)

  integer ier, zonetype
  integer n,nn,mm,i,j,k,idim

  integer cg_in, cg_out, base, zone, zoneCounter

  integer :: ptSetType, normalDataType
  integer :: sizes(9),coordID,blockStart(3),blockEnd(3)

  integer donor_range(6),transform(3)
  integer nbocos,n1to1,bocotype,BCout
  integer NormalIndex(3), NormalListFlag, ndataset,datatype
  integer ptset_type, npnts, pnts(3,2),pnts_donor(3,2),ncon

  character*32 in_filename,out_filename
  character*32 basename, zonename,boconame
  character*32 connectname,donorname, famname
  double precision, allocatable,dimension(:,:,:) :: data3d
  double precision data_double(6)

  N = IARGC ()
  if (N .ne. 2) then
     print *,'Error: cgns_split must be called with TWO arguments:'
     print *,'./cgns_coarsen cgns_in_file.cgns cgns_out_file.cgns'
     stop
  end if

  call getarg(1, in_filename)
  call getarg(2, out_filename)

  call cg_open_f(in_filename,CG_MODE_READ, cg_in, ier)

  if (ier .eq. CG_ERROR) call cg_error_exit_f
  print *,'Reading input file: ',in_filename

  call cg_nbases_f(cg_in, nbases, ier)
  if (ier .eq. CG_ERROR) call cg_error_exit_f

  if (nbases .lt. 1) then
     print *, 'Error: No bases found in CGNS file'
  else if(nbases .gt. 1) then
     print *, 'Warning: More than one base found. Using only the first base'
  end if

  ! Explicitly use ONLY the first base
  base = 1

  call cg_base_read_f(cg_in, base, basename, CellDim, PhysDim, ier)
  if (ier .eq. CG_ERROR) call cg_error_exit_f
  if (cellDim .ne. 3 .or. PhysDim .ne. 3) then
     print *,'The Cells must be hexahedreal in 3 dimensions'
     stop
  end if

  ! Goto Base Node
  call cg_goto_f(cg_in, base, ier, 'end')
  call cg_nzones_f(cg_in, base, nzones, ier)

  ! Open the output file:
  call cg_open_f(out_filename,CG_MODE_WRITE, cg_out, ier)
  if (ier .eq. CG_ERROR) call cg_error_exit_f

  call cg_base_write_f(cg_out,"Base#1", Celldim,Physdim, base, ier)
  if (ier .eq. CG_ERROR) call cg_error_exit_f
  
  do nn=1,nzones
     call cg_zone_read_f(cg_in, base, nn, zonename, in_dims, ier)
     
     do i=1,3
        out_dims(i) = (in_dims(i)-1)/2 + 1
     end do
     do i=4,6
        out_dims(i) = in_dims(i)/2
     end do

     call cg_zone_write_f(cg_out,base,zonename,out_dims,Structured,zoneCounter,ier)

     allocate(data3d(in_dims(1),in_dims(2),in_dims(3)))

     blockStart = (/1,1,1/)
     blockEnd   = in_dims(1:3)

     ! X coordinate
     call cg_coord_read_f(cg_in,base,nn,'CoordinateX',RealDouble,&
          blockStart,blockEnd,data3d,ier)
     if (ier .eq. CG_ERROR) call cg_error_exit_f
     
     call cg_coord_write_f(cg_out,base,zoneCounter,realDouble,&
          'CoordinateX',data3d(1::2,1::2,1::2), coordID,ier)

     ! Y coordinate
     call cg_coord_read_f(cg_in,base,nn,'CoordinateY',RealDouble,&
          blockStart,blockEnd,data3d,ier)
     if (ier .eq. CG_ERROR) call cg_error_exit_f
     
     call cg_coord_write_f(cg_out,base,zoneCounter,realDouble,&
          'CoordinateY',data3d(1::2,1::2,1::2), coordID,ier)

     ! Z coordinate
     call cg_coord_read_f(cg_in,base,nn,'CoordinateZ',RealDouble,&
          blockStart,blockEnd,data3d,ier)
     if (ier .eq. CG_ERROR) call cg_error_exit_f
     
     call cg_coord_write_f(cg_out,base,zoneCounter,realDouble,&
          'CoordinateZ',data3d(1::2,1::2,1::2), coordID,ier)
     
     deallocate(data3d)

     ! Next to the BC's if there are any:
     
     call cg_nbocos_f(cg_in, base, nn, nBocos,ier)

     do mm=1,nBocos
        ! Get Boundary Condition Info
        call cg_boco_info_f(cg_in, base, nn, mm , boconame,bocotype,&
             ptset_type,npnts,NormalIndex,NormalListFlag,datatype,ndataset,ier)
        call cg_boco_read_f(cg_in, base, nn, mm, pnts,data_double, ier)

        ! Process the point range:
        do i=1,3
           do j=1,2
              pnts(i,j) = (pnts(i,j)-1)/2+1
           end do
        end do

        ! Write Boundary Condition Info:
        call cg_boco_write_f(cg_out,base,nn,boconame, bocotype, PointRange, &
             2, pnts, BCout ,  ier )
        if (ier .eq. CG_ERROR) call cg_error_exit_f

        ! Get/Write the Family Info
        call cg_goto_f(cg_in,base,ier,"Zone_t",nn,"ZoneBC_t",1,"BC_t",mm,"end")
        if (ier == 0) then ! Node exits
           call cg_famname_read_f(famName, ier)

           call cg_goto_f(cg_out,base,ier,'Zone_t', nn,"ZoneBC_t", 1,&
                "BC_t", BCOut, "end")
           call cg_famname_write_f(famName, ier)
        end if
     end do

     ! Next read the 1to1 Connectivity if there are any:
     call cg_n1to1_f(cg_in, base, nn, n1to1, ier)

     do mm=1,n1to1
        call cg_1to1_read_f(cg_in, base, nn, mm, connectName, donorname, &
             pnts,pnts_donor, transform, ier)
        
        ! Process the point range:
        do i=1,3
           do j=1,2
              pnts(i,j) = (pnts(i,j)-1)/2+1
              pnts_donor(i,j) = (pnts_donor(i,j)-1)/2+1
           end do
        end do

        call cg_1to1_write_f(cg_out,base,nn,connectName,donorname,&
             pnts,pnts_donor,transform,nCon,ier)

     end do ! 1ot1 Loop


  end do ! Zone Loop

  ! Close both CGNS files
  call cg_close_f(cg_in, ier)
  call cg_close_f(cg_out,ier)

end program cgns_coarsen

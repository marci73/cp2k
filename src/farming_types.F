!--------------------------------------------------------------------------------------------------!
!   CP2K: A general program to perform molecular dynamics simulations                              !
!   Copyright 2000-2025 CP2K developers group <https://cp2k.org>                                   !
!                                                                                                  !
!   SPDX-License-Identifier: GPL-2.0-or-later                                                      !
!--------------------------------------------------------------------------------------------------!

! **************************************************************************************************
MODULE farming_types

   USE kinds,                           ONLY: default_path_length,&
                                              dp
#include "./base/base_uses.f90"

   IMPLICIT NONE
   PRIVATE

   PUBLIC :: farming_env_type, deallocate_farming_env, init_farming_env, init_job_type

   INTEGER, PUBLIC, PARAMETER :: job_pending = 1, job_running = 2, job_finished = 3

! **************************************************************************************************
   TYPE job_type
      CHARACTER(LEN=default_path_length) :: cwd = "" ! the directory to go to
      CHARACTER(LEN=default_path_length) :: input = "" ! the input file to use
      CHARACTER(LEN=default_path_length) :: output = "" ! the output file to use
      INTEGER                            :: ID = -1 ! the ID of this job
      INTEGER, POINTER, DIMENSION(:)     :: dependencies => NULL() ! the dependencies of this job
      INTEGER                            :: status = -1 ! pending,running,finished
   END TYPE job_type

! **************************************************************************************************
   TYPE farming_env_type
      INTEGER :: group_size_wish = -1
      LOGICAL :: group_size_wish_set = .FALSE.
      INTEGER :: ngroup_wish = -1
      LOGICAL :: ngroup_wish_set = .FALSE.
      LOGICAL :: restart = .FALSE.
      LOGICAL :: CYCLE = .FALSE.
      LOGICAL :: captain_minion = .FALSE.
      INTEGER, DIMENSION(:), POINTER                              :: group_partition => NULL() ! user preference for partitioning the cpus
      CHARACTER(LEN=default_path_length)                          :: restart_file_name = "" ! restart file for farming
      CHARACTER(LEN=default_path_length)                          :: cwd = "" ! directory we started from
      INTEGER                                                     :: Njobs = -1 ! how many jobs to run
      INTEGER                                                     :: restart_n = -1 ! where to start
      INTEGER                                                     :: max_steps = -1 ! max number of steps,
      ! results in max_steps*Ngroup jobs being run
      INTEGER                                                     :: stride = -1 ! for creating minion groups.
      TYPE(job_type), DIMENSION(:), POINTER                       :: job => NULL() ! a list of jobs
      REAL(KIND=dp) :: wait_time = 0.0_dp
   END TYPE farming_env_type

CONTAINS

! **************************************************************************************************
!> \brief help poor compilers do their job
!>       i.e. provide a default initialization
!> \param farming_env an associated farming env pointer
!> \par History
!>      03.2004 created [Joost VandeVondele ]
! **************************************************************************************************
   SUBROUTINE init_farming_env(farming_env)
      TYPE(farming_env_type), POINTER                    :: farming_env

      IF (ASSOCIATED(farming_env)) THEN
         farming_env%group_size_wish = 0
         farming_env%group_size_wish_set = .FALSE.
         farming_env%ngroup_wish = 0
         farming_env%ngroup_wish_set = .FALSE.
         farming_env%restart = .FALSE.
         farming_env%restart_n = 1
         farming_env%cycle = .FALSE.
         farming_env%captain_minion = .FALSE.
         NULLIFY (farming_env%group_partition)
         farming_env%cwd = "."
         farming_env%Njobs = 0
         ! so that maxsteps*ngroup is (likely) not overflowing
         farming_env%max_steps = 65535
         NULLIFY (farming_env%Job)
      END IF
   END SUBROUTINE

! **************************************************************************************************
!> \brief provide a default initialization
!> \param job ...
!> \par History
!>      09.2007 created [Joost VandeVondele ]
! **************************************************************************************************
   ELEMENTAL SUBROUTINE init_job_type(job)
      TYPE(job_type), INTENT(OUT)                        :: job

      job%cwd = ""
      job%input = ""
      job%output = ""
      job%ID = -1
      job%status = job_pending
      NULLIFY (job%dependencies)

   END SUBROUTINE init_job_type

! **************************************************************************************************
!> \brief deallocates all memory associated with this job
!> \param job ...
!> \par History
!>      09.2007 created [Joost VandeVondele ]
! **************************************************************************************************
   SUBROUTINE deallocate_job_type(job)
      TYPE(job_type)                                     :: job

      IF (ASSOCIATED(job%dependencies)) DEALLOCATE (job%dependencies)

   END SUBROUTINE deallocate_job_type

! **************************************************************************************************
!> \brief deallocates all associated fields of the farming_env type
!>      and the type itself
!> \param farming_env ...
!> \par History
!>      03.2004 created [Joost VandeVondele]
! **************************************************************************************************
   SUBROUTINE deallocate_farming_env(farming_env)
      TYPE(farming_env_type), POINTER                    :: farming_env

      INTEGER                                            :: I

      IF (ASSOCIATED(farming_env)) THEN
         IF (ASSOCIATED(farming_env%job)) THEN
            DO I = 1, SIZE(farming_env%job, 1)
               CALL deallocate_job_type(farming_env%job(I))
            END DO
            DEALLOCATE (farming_env%job)
         END IF
         IF (ASSOCIATED(farming_env%group_partition)) DEALLOCATE (farming_env%group_partition)
         DEALLOCATE (farming_env) ! and the type itself
      END IF
   END SUBROUTINE deallocate_farming_env
END MODULE farming_types

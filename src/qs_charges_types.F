!--------------------------------------------------------------------------------------------------!
!   CP2K: A general program to perform molecular dynamics simulations                              !
!   Copyright 2000-2025 CP2K developers group <https://cp2k.org>                                   !
!                                                                                                  !
!   SPDX-License-Identifier: GPL-2.0-or-later                                                      !
!--------------------------------------------------------------------------------------------------!

! **************************************************************************************************
!> \brief container for information about total charges on the grids
!> \par History
!>      10.2002 created [fawzi]
!> \author Fawzi Mohamed
! **************************************************************************************************
MODULE qs_charges_types

   USE kinds,                           ONLY: dp
#include "./base/base_uses.f90"

   IMPLICIT NONE
   PRIVATE

   LOGICAL, PRIVATE, PARAMETER :: debug_this_module = .TRUE.
   CHARACTER(len=*), PARAMETER, PRIVATE :: moduleN = 'qs_charges_types'

   PUBLIC :: qs_charges_type
   PUBLIC :: qs_charges_create, qs_charges_release
!***

! **************************************************************************************************
!> \brief Container for information about total charges on the grids
!> \param total_rho_core_rspace total charge on the rho_core grid
!> \param total_rho_rspace total charge in the real space
!> \param total_rho_gspace total charge in the g space
!> \note
!>      this type is losing the reason to exist...
!> \par History
!>      10.2002 created [fawzi]
!>      11.2002 moved total_rho_elec_rspace to qs_rho_type
!> \author Fawzi Mohamed
! **************************************************************************************************
   TYPE qs_charges_type
      REAL(KIND=dp) :: total_rho_core_rspace = -1.0_dp, total_rho_gspace = -1.0_dp
      REAL(KIND=dp) :: total_rho0_soft_rspace = -1.0_dp, total_rho0_hard_lebedev = -1.0_dp
      REAL(KIND=dp) :: total_rho_soft_gspace = -1.0_dp
      REAL(KIND=dp), DIMENSION(:), POINTER  :: total_rho1_hard => NULL(), &
                                               total_rho1_soft => NULL()
      REAL(KIND=dp) :: background = -1.0_dp
   END TYPE qs_charges_type

CONTAINS

! **************************************************************************************************
!> \brief creates a charges object
!> \param qs_charges the charges object to create
!> \param nspins ...
!> \param total_rho_core_rspace ...
!> \param total_rho_gspace ...
!> \par History
!>      10.2002 created [fawzi]
!> \author Fawzi Mohamed
! **************************************************************************************************
   SUBROUTINE qs_charges_create(qs_charges, nspins, total_rho_core_rspace, &
                                total_rho_gspace)
      TYPE(qs_charges_type), INTENT(OUT)                 :: qs_charges
      INTEGER, INTENT(in)                                :: nspins
      REAL(KIND=dp), INTENT(in), OPTIONAL                :: total_rho_core_rspace, total_rho_gspace

      qs_charges%total_rho_core_rspace = 0.0_dp
      IF (PRESENT(total_rho_core_rspace)) &
         qs_charges%total_rho_core_rspace = total_rho_core_rspace
      qs_charges%total_rho_gspace = 0.0_dp
      IF (PRESENT(total_rho_gspace)) &
         qs_charges%total_rho_gspace = total_rho_gspace
      qs_charges%total_rho_soft_gspace = 0.0_dp
      qs_charges%total_rho0_hard_lebedev = 0.0_dp
      qs_charges%total_rho_soft_gspace = 0.0_dp
      qs_charges%background = 0.0_dp
      ALLOCATE (qs_charges%total_rho1_hard(nspins))
      qs_charges%total_rho1_hard(:) = 0.0_dp
      ALLOCATE (qs_charges%total_rho1_soft(nspins))
      qs_charges%total_rho1_soft(:) = 0.0_dp
   END SUBROUTINE qs_charges_create

! **************************************************************************************************
!> \brief releases the charges object (see cp2k/doc/ReferenceCounting.html)
!> \param qs_charges the object to be released
!> \par History
!>      10.2002 created [fawzi]
!> \author Fawzi Mohamed
! **************************************************************************************************
   SUBROUTINE qs_charges_release(qs_charges)
      TYPE(qs_charges_type), INTENT(INOUT)               :: qs_charges

      DEALLOCATE (qs_charges%total_rho1_hard)
      DEALLOCATE (qs_charges%total_rho1_soft)

   END SUBROUTINE qs_charges_release

END MODULE qs_charges_types

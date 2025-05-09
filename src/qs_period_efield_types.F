!--------------------------------------------------------------------------------------------------!
!   CP2K: A general program to perform molecular dynamics simulations                              !
!   Copyright 2000-2025 CP2K developers group <https://cp2k.org>                                   !
!                                                                                                  !
!   SPDX-License-Identifier: GPL-2.0-or-later                                                      !
!--------------------------------------------------------------------------------------------------!

! **************************************************************************************************
!> \brief type for berry phase efield matrices. At the moment only used for
!>        cosmat and sinmat
!> \par History
!>      none
!> \author fschiff (06.2010)
! **************************************************************************************************

MODULE qs_period_efield_types

   USE cp_dbcsr_api,                    ONLY: dbcsr_p_type
   USE cp_dbcsr_operations,             ONLY: dbcsr_deallocate_matrix_set
   USE kinds,                           ONLY: dp
#include "./base/base_uses.f90"

   IMPLICIT NONE

   PRIVATE

   CHARACTER(len=*), PARAMETER, PRIVATE :: moduleN = 'qs_period_efield_types'

   PUBLIC :: efield_berry_type, efield_berry_release, init_efield_matrices, &
             set_efield_matrices

   TYPE efield_berry_type
      REAL(KIND=dp)                                          :: field_energy = -1.0_dp
      REAL(KIND=dp), DIMENSION(3)                            :: polarisation = -1.0_dp
      TYPE(dbcsr_p_type), DIMENSION(:), POINTER           :: cosmat => NULL()
      TYPE(dbcsr_p_type), DIMENSION(:), POINTER           :: sinmat => NULL()
      TYPE(dbcsr_p_type), DIMENSION(:), POINTER           :: dipmat => NULL()
   END TYPE efield_berry_type

CONTAINS

! **************************************************************************************************
!> \brief ...
!> \param efield ...
! **************************************************************************************************
   SUBROUTINE init_efield_matrices(efield)
      TYPE(efield_berry_type), POINTER                   :: efield

      REAL(KIND=dp)                                      :: field_energy
      REAL(KIND=dp), DIMENSION(3)                        :: polarisation

! retain possible values for energy and polarisation

      IF (ASSOCIATED(efield)) THEN
         field_energy = efield%field_energy
         polarisation = efield%polarisation
         CALL efield_berry_release(efield)
      ELSE
         field_energy = 0.0_dp
         polarisation = 0.0_dp
      END IF

      ALLOCATE (efield)
      NULLIFY (efield%cosmat)
      NULLIFY (efield%sinmat)
      NULLIFY (efield%dipmat)

      efield%field_energy = field_energy
      efield%polarisation = polarisation

   END SUBROUTINE init_efield_matrices

! **************************************************************************************************
!> \brief ...
!> \param efield ...
!> \param sinmat ...
!> \param cosmat ...
!> \param dipmat ...
! **************************************************************************************************
   SUBROUTINE set_efield_matrices(efield, sinmat, cosmat, dipmat)

      TYPE(efield_berry_type), POINTER                   :: efield
      TYPE(dbcsr_p_type), DIMENSION(:), OPTIONAL, &
         POINTER                                         :: sinmat, cosmat, dipmat

      IF (PRESENT(cosmat)) efield%cosmat => cosmat
      IF (PRESENT(sinmat)) efield%sinmat => sinmat
      IF (PRESENT(dipmat)) efield%dipmat => dipmat

   END SUBROUTINE set_efield_matrices

! **************************************************************************************************
!> \brief ...
!> \param efield ...
! **************************************************************************************************
   SUBROUTINE efield_berry_release(efield)
      TYPE(efield_berry_type), POINTER                   :: efield

      IF (ASSOCIATED(efield)) THEN
         IF (ASSOCIATED(efield%sinmat) .AND. ASSOCIATED(efield%cosmat)) THEN
            CALL dbcsr_deallocate_matrix_set(efield%cosmat)
            CALL dbcsr_deallocate_matrix_set(efield%sinmat)
         END IF
         IF (ASSOCIATED(efield%dipmat)) THEN
            CALL dbcsr_deallocate_matrix_set(efield%dipmat)
         END IF
         DEALLOCATE (efield)
      END IF
   END SUBROUTINE efield_berry_release

END MODULE qs_period_efield_types

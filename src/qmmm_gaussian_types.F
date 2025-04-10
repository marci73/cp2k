!--------------------------------------------------------------------------------------------------!
!   CP2K: A general program to perform molecular dynamics simulations                              !
!   Copyright 2000-2025 CP2K developers group <https://cp2k.org>                                   !
!                                                                                                  !
!   SPDX-License-Identifier: GPL-2.0-or-later                                                      !
!--------------------------------------------------------------------------------------------------!

! **************************************************************************************************
!> \brief Sets the typo for the gaussian treatment of the qm/mm interaction
!> \par History
!>      06.2004 created
!> \author Teodoro Laino
! **************************************************************************************************
MODULE qmmm_gaussian_types

   USE kinds,                           ONLY: dp
#include "./base/base_uses.f90"

   IMPLICIT NONE
   PRIVATE

! **************************************************************************************************
!> \par History
!>      06.2004 created [tlaino]
!> \author Laino Teodoro
! **************************************************************************************************
   TYPE qmmm_gaussian_type
      INTEGER                               :: number_of_gaussians = -1
      REAL(KIND=dp)                         :: Elp_Radius = -1.0_dp, Elp_Radius_Corr = -1.0_dp
      INTEGER, DIMENSION(:), POINTER        :: grid_level => NULL()
      REAL(KIND=dp), DIMENSION(:), POINTER  :: Ak => NULL(), Gk => NULL()
   END TYPE qmmm_gaussian_type

! **************************************************************************************************
!> \brief represent a pointer to a qmmm_gaussian_type, to be able to create arrays
!>      of pointers
!> \param qmmm_gaussian_type the pointer to the qmmm_gaussian_type
!> \par History
!>      06.2004 created [tlaino]
!> \author Teodoro Laino
! **************************************************************************************************
   TYPE qmmm_gaussian_p_type
      TYPE(qmmm_gaussian_type), POINTER :: pgf => NULL()
   END TYPE qmmm_gaussian_p_type

   PUBLIC  :: qmmm_gaussian_type, &
              qmmm_gaussian_p_type

END MODULE qmmm_gaussian_types


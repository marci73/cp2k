!--------------------------------------------------------------------------------------------------!
!   CP2K: A general program to perform molecular dynamics simulations                              !
!   Copyright 2000-2025 CP2K developers group <https://cp2k.org>                                   !
!                                                                                                  !
!   SPDX-License-Identifier: GPL-2.0-or-later                                                      !
!--------------------------------------------------------------------------------------------------!

! **************************************************************************************************
!> \par History
!>      none
! **************************************************************************************************
MODULE dg_rho0_types

   USE kinds,                           ONLY: dp
   USE pw_grid_types,                   ONLY: pw_grid_type
   USE pw_methods,                      ONLY: pw_zero
   USE pw_poisson_types,                ONLY: do_ewald_ewald,&
                                              do_ewald_none,&
                                              do_ewald_pme,&
                                              do_ewald_spme
   USE pw_types,                        ONLY: pw_r3d_rs_type
#include "../base/base_uses.f90"

   IMPLICIT NONE

   PRIVATE
   PUBLIC:: dg_rho0_type, dg_rho0_init, dg_rho0_set, dg_rho0_get, &
            dg_rho0_create, dg_rho0_release

   CHARACTER(len=*), PARAMETER, PRIVATE :: moduleN = 'dg_rho0_types'

! **************************************************************************************************
!> \brief   Type for Gaussian Densities
!>              type = type of gaussian (PME)
!>              grid = grid number
!>              gcc = Gaussian contraction coefficient
!>              zet = Gaussian exponent
! **************************************************************************************************
   TYPE dg_rho0_type
      INTEGER :: TYPE = do_ewald_none
      INTEGER :: grid = 0
      INTEGER :: kind = 0
      REAL(KIND=dp) :: cutoff_radius = 0.0_dp
      REAL(KIND=dp), DIMENSION(:), POINTER :: gcc => NULL()
      REAL(KIND=dp), DIMENSION(:), POINTER :: zet => NULL()
      TYPE(pw_r3d_rs_type), POINTER :: density => NULL()
   END TYPE dg_rho0_type

CONTAINS

! **************************************************************************************************
!> \brief   Set the dg_rho0_type
!> \param dg_rho0 ...
!> \param TYPE ...
!> \param grid ...
!> \param kind ...
!> \param cutoff_radius ...
!> \param gcc ...
!> \param zet ...
!> \param density ...
!> \version 1.0
! **************************************************************************************************
   SUBROUTINE dg_rho0_set(dg_rho0, TYPE, grid, kind, cutoff_radius, &
                          gcc, zet, density)
      INTEGER, OPTIONAL                                  :: TYPE
      TYPE(dg_rho0_type), POINTER                        :: dg_rho0
      INTEGER, OPTIONAL                                  :: grid, kind
      REAL(KIND=dp), OPTIONAL                            :: cutoff_radius
      REAL(KIND=dp), OPTIONAL, POINTER                   :: gcc(:), zet(:)
      TYPE(pw_r3d_rs_type), OPTIONAL, POINTER            :: density

      IF (PRESENT(grid)) dg_rho0%grid = grid
      IF (PRESENT(kind)) dg_rho0%kind = kind
      IF (PRESENT(density)) dg_rho0%density => density
      IF (PRESENT(gcc)) dg_rho0%gcc => gcc
      IF (PRESENT(zet)) dg_rho0%zet => zet
      IF (PRESENT(TYPE)) dg_rho0%type = TYPE
      IF (PRESENT(cutoff_radius)) dg_rho0%cutoff_radius = cutoff_radius

   END SUBROUTINE dg_rho0_set

! **************************************************************************************************
!> \brief  Get the dg_rho0_type
!> \param dg_rho0 ...
!> \param cutoff_radius ...
!> \param TYPE ...
!> \param grid ...
!> \param kind ...
!> \param gcc ...
!> \param zet ...
!> \param density ...
!> \version 1.0
! **************************************************************************************************
   SUBROUTINE dg_rho0_get(dg_rho0, cutoff_radius, TYPE, grid, kind, gcc, zet, density)
      INTEGER, OPTIONAL                                  :: TYPE
      REAL(KIND=dp), OPTIONAL                            :: cutoff_radius
      TYPE(dg_rho0_type), POINTER                        :: dg_rho0
      INTEGER, OPTIONAL                                  :: grid, kind
      REAL(KIND=dp), OPTIONAL, POINTER                   :: gcc(:), zet(:)
      TYPE(pw_r3d_rs_type), OPTIONAL, POINTER            :: density

      IF (PRESENT(grid)) grid = dg_rho0%grid
      IF (PRESENT(kind)) kind = dg_rho0%kind
      IF (PRESENT(density)) density => dg_rho0%density
      IF (PRESENT(gcc)) gcc => dg_rho0%gcc
      IF (PRESENT(zet)) zet => dg_rho0%zet
      IF (PRESENT(TYPE)) TYPE = dg_rho0%type
      IF (PRESENT(cutoff_radius)) cutoff_radius = dg_rho0%cutoff_radius

   END SUBROUTINE dg_rho0_get

! **************************************************************************************************
!> \brief   create the dg_rho0 structure
!> \param dg_rho0 ...
!> \version 1.0
! **************************************************************************************************
   SUBROUTINE dg_rho0_create(dg_rho0)
      TYPE(dg_rho0_type), POINTER                        :: dg_rho0

      ALLOCATE (dg_rho0)

   END SUBROUTINE dg_rho0_create

! **************************************************************************************************
!> \brief releases the given dg_rho0_type
!> \param dg_rho0 the dg_rho0_type to release
!> \par History
!>      04.2003 created [fawzi]
!> \author fawzi
!> \note
!>      see doc/ReferenceCounting.html
! **************************************************************************************************
   SUBROUTINE dg_rho0_release(dg_rho0)
      TYPE(dg_rho0_type), POINTER                        :: dg_rho0

      IF (ASSOCIATED(dg_rho0)) THEN
         IF (ASSOCIATED(dg_rho0%gcc)) THEN
            DEALLOCATE (dg_rho0%gcc)
         END IF
         IF (ASSOCIATED(dg_rho0%zet)) THEN
            DEALLOCATE (dg_rho0%zet)
         END IF
         IF (ASSOCIATED(dg_rho0%density)) THEN
            CALL dg_rho0%density%release()
            DEALLOCATE (dg_rho0%density)
         END IF
         NULLIFY (dg_rho0%gcc)
         NULLIFY (dg_rho0%zet)
         DEALLOCATE (dg_rho0)
      END IF
      NULLIFY (dg_rho0)
   END SUBROUTINE dg_rho0_release

! **************************************************************************************************
!> \brief ...
!> \param dg_rho0 ...
!> \param pw_grid ...
! **************************************************************************************************
   SUBROUTINE dg_rho0_init(dg_rho0, pw_grid)
      TYPE(dg_rho0_type), POINTER                        :: dg_rho0
      TYPE(pw_grid_type), POINTER                        :: pw_grid

      IF (ASSOCIATED(dg_rho0%density)) THEN
         CALL dg_rho0%density%release()
      ELSE
         ALLOCATE (dg_rho0%density)
      END IF
      SELECT CASE (dg_rho0%type)
      CASE (do_ewald_ewald)
         CALL dg_rho0%density%create(pw_grid)
         CALL dg_rho0_pme_gauss(dg_rho0%density, dg_rho0%zet(1))
      CASE (do_ewald_pme)
         CALL dg_rho0%density%create(pw_grid)
         CALL dg_rho0_pme_gauss(dg_rho0%density, dg_rho0%zet(1))
      CASE (do_ewald_spme)
         CPABORT('SPME type not implemented')
      END SELECT

   END SUBROUTINE dg_rho0_init

! **************************************************************************************************
!> \brief ...
!> \param dg_rho0 ...
!> \param alpha ...
! **************************************************************************************************
   SUBROUTINE dg_rho0_pme_gauss(dg_rho0, alpha)

      TYPE(pw_r3d_rs_type), INTENT(INOUT)                :: dg_rho0
      REAL(KIND=dp), INTENT(IN)                          :: alpha

      INTEGER, PARAMETER                                 :: IMPOSSIBLE = 10000

      INTEGER                                            :: gpt, l0, ln, lp, m0, mn, mp, n0, nn, np
      INTEGER, DIMENSION(:, :), POINTER                  :: bds
      REAL(KIND=dp)                                      :: const, e_gsq
      REAL(KIND=dp), DIMENSION(:, :, :), POINTER         :: rho0
      TYPE(pw_grid_type), POINTER                        :: pw_grid

      const = 1.0_dp/(8.0_dp*alpha**2)

      pw_grid => dg_rho0%pw_grid
      bds => pw_grid%bounds

      IF (-bds(1, 1) == bds(2, 1)) THEN
         l0 = IMPOSSIBLE
      ELSE
         l0 = bds(1, 1)
      END IF

      IF (-bds(1, 2) == bds(2, 2)) THEN
         m0 = IMPOSSIBLE
      ELSE
         m0 = bds(1, 2)
      END IF

      IF (-bds(1, 3) == bds(2, 3)) THEN
         n0 = IMPOSSIBLE
      ELSE
         n0 = bds(1, 3)
      END IF

      CALL pw_zero(dg_rho0)

      rho0 => dg_rho0%array

      DO gpt = 1, pw_grid%ngpts_cut_local
         ASSOCIATE (ghat => pw_grid%g_hat(:, gpt))

            lp = pw_grid%mapl%pos(ghat(1))
            ln = pw_grid%mapl%neg(ghat(1))
            mp = pw_grid%mapm%pos(ghat(2))
            mn = pw_grid%mapm%neg(ghat(2))
            np = pw_grid%mapn%pos(ghat(3))
            nn = pw_grid%mapn%neg(ghat(3))

            e_gsq = EXP(-const*pw_grid%gsq(gpt))/pw_grid%vol

            lp = lp + bds(1, 1)
            mp = mp + bds(1, 2)
            np = np + bds(1, 3)
            ln = ln + bds(1, 1)
            mn = mn + bds(1, 2)
            nn = nn + bds(1, 3)

            rho0(lp, mp, np) = e_gsq
            rho0(ln, mn, nn) = e_gsq

            IF (ghat(1) == l0 .OR. ghat(2) == m0 .OR. ghat(3) == n0) THEN
               rho0(lp, mp, np) = 0.0_dp
               rho0(ln, mn, nn) = 0.0_dp
            END IF
         END ASSOCIATE

      END DO

   END SUBROUTINE dg_rho0_pme_gauss

END MODULE dg_rho0_types

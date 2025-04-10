!--------------------------------------------------------------------------------------------------!
!   CP2K: A general program to perform molecular dynamics simulations                              !
!   Copyright 2000-2025 CP2K developers group <https://cp2k.org>                                   !
!                                                                                                  !
!   SPDX-License-Identifier: GPL-2.0-or-later                                                      !
!--------------------------------------------------------------------------------------------------!

! **************************************************************************************************
!> \brief  Data type and methods dealing with PI calcs in normal mode coords
!> \author fawzi
!> \par    History
!>         2006-02 created
!>         2006-11 modified so it might actually work [hforbert]
!>         2009-04-07 moved from pint_types module to a separate file [lwalewski]
!>         2015-10 added alternative normal mode transformation needed by RPMD
!>                 [Felix Uhl
! **************************************************************************************************
MODULE pint_normalmode
   USE input_constants,                 ONLY: propagator_cmd,&
                                              propagator_pimd,&
                                              propagator_rpmd
   USE input_section_types,             ONLY: section_vals_type,&
                                              section_vals_val_get
   USE kinds,                           ONLY: dp
   USE mathconstants,                   ONLY: pi,&
                                              twopi
   USE pint_types,                      ONLY: normalmode_env_type
#include "../base/base_uses.f90"

   IMPLICIT NONE
   PRIVATE

   LOGICAL, PRIVATE, PARAMETER :: debug_this_module = .TRUE.
   CHARACTER(len=*), PARAMETER, PRIVATE :: moduleN = 'pint_normalmode'

   PUBLIC :: normalmode_env_create
   PUBLIC :: normalmode_release
   PUBLIC :: normalmode_init_masses
   PUBLIC :: normalmode_x2u
   PUBLIC :: normalmode_u2x
   PUBLIC :: normalmode_f2uf
   PUBLIC :: normalmode_calc_uf_h

CONTAINS

! ***************************************************************************
!> \brief creates the data needed for a normal mode transformation
!> \param normalmode_env ...
!> \param normalmode_section ...
!> \param p ...
!> \param kT ...
!> \param propagator ...
!> \author Harald Forbert
! **************************************************************************************************
   SUBROUTINE normalmode_env_create(normalmode_env, normalmode_section, p, kT, propagator)
      TYPE(normalmode_env_type), INTENT(OUT)             :: normalmode_env
      TYPE(section_vals_type), POINTER                   :: normalmode_section
      INTEGER, INTENT(in)                                :: p
      REAL(kind=dp), INTENT(in)                          :: kT
      INTEGER, INTENT(in)                                :: propagator

      INTEGER                                            :: i, j, k, li
      LOGICAL                                            :: explicit_gamma, explicit_modefactor
      REAL(kind=dp)                                      :: gamma_parameter, invsqrtp, pip, sqrt2p, &
                                                            twopip

      ALLOCATE (normalmode_env%x2u(p, p))
      ALLOCATE (normalmode_env%u2x(p, p))
      ALLOCATE (normalmode_env%lambda(p))

      normalmode_env%p = p

      CALL section_vals_val_get(normalmode_section, "Q_CENTROID", &
                                r_val=normalmode_env%Q_centroid)
      CALL section_vals_val_get(normalmode_section, "Q_BEAD", &
                                r_val=normalmode_env%Q_bead)
      CALL section_vals_val_get(normalmode_section, "MODEFACTOR", &
                                explicit=explicit_modefactor, &
                                r_val=normalmode_env%modefactor)
      CALL section_vals_val_get(normalmode_section, "GAMMA", &
                                r_val=gamma_parameter, &
                                explicit=explicit_gamma)

      IF (explicit_modefactor .AND. explicit_gamma) THEN
         CPABORT("Both GAMMA and MODEFACTOR have been declared. Please use only one.")
      END IF
      IF (explicit_gamma) THEN
         normalmode_env%modefactor = 1.0_dp/gamma_parameter**2
      END IF

      IF (propagator == propagator_cmd) THEN
         IF (.NOT. explicit_gamma) THEN
            CPABORT("GAMMA needs to be specified with CMD PROPAGATOR")
         END IF
         IF (gamma_parameter <= 1.0_dp) THEN
            CPWARN("GAMMA should be larger than 1.0 for CMD PROPAGATOR")
         END IF
      END IF

      IF (normalmode_env%Q_centroid < 0.0_dp) THEN
         normalmode_env%Q_centroid = -normalmode_env%Q_centroid/(kT*p)
      END IF
      IF (normalmode_env%Q_bead < 0.0_dp) THEN
         normalmode_env%Q_bead = -normalmode_env%Q_bead/(kT*p)
      END IF

      !Use different normal mode transformations depending on the propagator
      IF (propagator == propagator_pimd .OR. propagator == propagator_cmd) THEN

         IF (propagator == propagator_pimd) THEN
            normalmode_env%harm = p*kT*kT/normalmode_env%modefactor
         ELSE IF (propagator == propagator_cmd) THEN
            normalmode_env%harm = p*kT*kT*gamma_parameter*gamma_parameter
            normalmode_env%modefactor = 1.0_dp/(gamma_parameter*gamma_parameter)
         END IF

         ! set up the transformation matrices
         DO i = 1, p
            normalmode_env%lambda(i) = 2.0_dp*(1.0_dp - COS(pi*(i/2)*2.0_dp/p))
            DO j = 1, p
               k = ((i/2)*(j - 1))/p
               k = (i/2)*(j - 1) - k*p
               li = 2*(i - 2*(i/2))*p - p
               normalmode_env%u2x(j, i) = SQRT(2.0_dp/p)*SIN(twopi*(k + 0.125_dp*li)/p)
            END DO
         END DO
         normalmode_env%lambda(1) = 1.0_dp/(p*normalmode_env%modefactor)
         DO i = 1, p
            DO j = 1, p
               normalmode_env%x2u(i, j) = SQRT(normalmode_env%lambda(i)* &
                                               normalmode_env%modefactor)* &
                                          normalmode_env%u2x(j, i)
            END DO
         END DO
         DO i = 1, p
            DO j = 1, p
               normalmode_env%u2x(i, j) = normalmode_env%u2x(i, j)/ &
                                          SQRT(normalmode_env%lambda(j)* &
                                               normalmode_env%modefactor)
            END DO
         END DO
         normalmode_env%lambda(:) = normalmode_env%harm

      ELSE IF (propagator == propagator_rpmd) THEN
         normalmode_env%harm = kT/normalmode_env%modefactor
         sqrt2p = SQRT(2.0_dp/REAL(p, dp))
         twopip = twopi/REAL(p, dp)
         pip = pi/REAL(p, dp)
         invsqrtp = 1.0_dp/SQRT(REAL(p, dp))
         normalmode_env%x2u(:, :) = 0.0_dp
         normalmode_env%x2u(1, :) = invsqrtp
         DO j = 1, p
            DO i = 2, p/2 + 1
               normalmode_env%x2u(i, j) = sqrt2p*COS(twopip*(i - 1)*(j - 1))
            END DO
            DO i = p/2 + 2, p
               normalmode_env%x2u(i, j) = sqrt2p*SIN(twopip*(i - 1)*(j - 1))
            END DO
         END DO
         IF (MOD(p, 2) == 0) THEN
            DO i = 1, p - 1, 2
               normalmode_env%x2u(p/2 + 1, i) = invsqrtp
               normalmode_env%x2u(p/2 + 1, i + 1) = -1.0_dp*invsqrtp
            END DO
         END IF

         normalmode_env%u2x = TRANSPOSE(normalmode_env%x2u)

         ! Setting up propagator frequencies for rpmd
         normalmode_env%lambda(1) = 0.0_dp
         DO i = 2, p
            normalmode_env%lambda(i) = 2.0_dp*normalmode_env%harm*SIN((i - 1)*pip)
            normalmode_env%lambda(i) = normalmode_env%lambda(i)*normalmode_env%lambda(i)
         END DO
         normalmode_env%harm = kT*kT
      ELSE
         CPABORT("UNKNOWN PROPAGATOR FOR PINT SELECTED")
      END IF

   END SUBROUTINE normalmode_env_create

! ***************************************************************************
!> \brief releases the normalmode environment
!> \param normalmode_env the normalmode_env to release
!> \author Harald Forbert
! **************************************************************************************************
   PURE SUBROUTINE normalmode_release(normalmode_env)

      TYPE(normalmode_env_type), INTENT(INOUT)           :: normalmode_env

      DEALLOCATE (normalmode_env%x2u)
      DEALLOCATE (normalmode_env%u2x)
      DEALLOCATE (normalmode_env%lambda)

   END SUBROUTINE normalmode_release

! ***************************************************************************
!> \brief initializes the masses and fictitious masses compatible with the
!>      normal mode information
!> \param normalmode_env the definition of the normal mode transformation
!> \param mass *input* the masses of the particles
!> \param mass_beads masses of the beads
!> \param mass_fict the fictitious masses
!> \param Q masses of the nose thermostats
!> \author Harald Forbert
! **************************************************************************************************
   PURE SUBROUTINE normalmode_init_masses(normalmode_env, mass, mass_beads, mass_fict, &
                                          Q)

      TYPE(normalmode_env_type), INTENT(IN)              :: normalmode_env
      REAL(kind=dp), DIMENSION(:), INTENT(in)            :: mass
      REAL(kind=dp), DIMENSION(:, :), INTENT(out), &
         OPTIONAL                                        :: mass_beads, mass_fict
      REAL(kind=dp), DIMENSION(:), INTENT(out), OPTIONAL :: Q

      INTEGER                                            :: iat, ib

      IF (PRESENT(Q)) THEN
         Q = normalmode_env%Q_bead
         Q(1) = normalmode_env%Q_centroid
      END IF
      IF (PRESENT(mass_beads) .OR. PRESENT(mass_fict)) THEN
         IF (PRESENT(mass_beads)) THEN
            DO iat = 1, SIZE(mass)
               mass_beads(1, iat) = 0.0_dp
               DO ib = 2, normalmode_env%p
                  mass_beads(ib, iat) = mass(iat)
               END DO
            END DO
         END IF
         IF (PRESENT(mass_fict)) THEN
            DO iat = 1, SIZE(mass)
               DO ib = 1, normalmode_env%p
                  mass_fict(ib, iat) = mass(iat)
               END DO
            END DO
         END IF
      END IF

   END SUBROUTINE normalmode_init_masses

! ***************************************************************************
!> \brief Transforms from the x into the u variables using a normal mode
!>      transformation for the positions
!> \param normalmode_env the environment for the normal mode transformation
!> \param ux will contain the u variable
!> \param x the positions to transform
!> \author Harald Forbert
! **************************************************************************************************
   SUBROUTINE normalmode_x2u(normalmode_env, ux, x)
      TYPE(normalmode_env_type), INTENT(INOUT)           :: normalmode_env
      REAL(kind=dp), DIMENSION(:, :), INTENT(out)        :: ux
      REAL(kind=dp), DIMENSION(:, :), INTENT(in)         :: x

      CALL DGEMM('N', 'N', normalmode_env%p, SIZE(x, 2), normalmode_env%p, 1.0_dp, &
                 normalmode_env%x2u(1, 1), SIZE(normalmode_env%x2u, 1), x(1, 1), SIZE(x, 1), &
                 0.0_dp, ux, SIZE(ux, 1))
   END SUBROUTINE normalmode_x2u

! ***************************************************************************
!> \brief transform from the u variable to the x (back normal mode
!>      transformation for the positions)
!> \param normalmode_env the environment for the normal mode transformation
!> \param ux the u variable (positions to be backtransformed)
!> \param x will contain the positions
!> \author Harald Forbert
! **************************************************************************************************
   SUBROUTINE normalmode_u2x(normalmode_env, ux, x)
      TYPE(normalmode_env_type), INTENT(INOUT)           :: normalmode_env
      REAL(kind=dp), DIMENSION(:, :), INTENT(in)         :: ux
      REAL(kind=dp), DIMENSION(:, :), INTENT(out)        :: x

      CALL DGEMM('N', 'N', normalmode_env%p, SIZE(ux, 2), normalmode_env%p, 1.0_dp, &
                 normalmode_env%u2x(1, 1), SIZE(normalmode_env%u2x, 1), ux(1, 1), SIZE(ux, 1), &
                 0.0_dp, x, SIZE(x, 1))
   END SUBROUTINE normalmode_u2x

! ***************************************************************************
!> \brief normalmode transformation for the forces
!> \param normalmode_env the environment for the normal mode transformation
!> \param uf will contain the forces for the transformed variables afterwards
!> \param f the forces to transform
!> \author Harald Forbert
! **************************************************************************************************
   SUBROUTINE normalmode_f2uf(normalmode_env, uf, f)
      TYPE(normalmode_env_type), INTENT(INOUT)           :: normalmode_env
      REAL(kind=dp), DIMENSION(:, :), INTENT(out)        :: uf
      REAL(kind=dp), DIMENSION(:, :), INTENT(in)         :: f

      CALL DGEMM('T', 'N', normalmode_env%p, SIZE(f, 2), normalmode_env%p, 1.0_dp, &
                 normalmode_env%u2x(1, 1), SIZE(normalmode_env%u2x, 1), f(1, 1), SIZE(f, 1), &
                 0.0_dp, uf, SIZE(uf, 1))
   END SUBROUTINE normalmode_f2uf

! ***************************************************************************
!> \brief calculates the harmonic force in the normal mode basis
!> \param normalmode_env the normal mode environment
!> \param mass_beads the masses of the beads
!> \param ux the positions of the beads in the staging basis
!> \param uf_h the harmonic forces (not accelerations)
!> \param e_h ...
!> \author Harald Forbert
! **************************************************************************************************
   PURE SUBROUTINE normalmode_calc_uf_h(normalmode_env, mass_beads, ux, uf_h, e_h)
      TYPE(normalmode_env_type), INTENT(IN)              :: normalmode_env
      REAL(kind=dp), DIMENSION(:, :), POINTER            :: mass_beads, ux, uf_h
      REAL(KIND=dp), INTENT(OUT)                         :: e_h

      INTEGER                                            :: ibead, idim
      REAL(kind=dp)                                      :: f

      e_h = 0.0_dp
      DO idim = 1, SIZE(mass_beads, 2)

         ! starting at 2 since the centroid is at 1 and it's mass_beads
         ! SHOULD be zero anyways:

         uf_h(1, idim) = 0.0_dp
         DO ibead = 2, normalmode_env%p
            f = -mass_beads(ibead, idim)*normalmode_env%lambda(ibead)*ux(ibead, idim)
            uf_h(ibead, idim) = f
            ! - to cancel the - in the force f.
            e_h = e_h - 0.5_dp*ux(ibead, idim)*f
         END DO

      END DO
   END SUBROUTINE normalmode_calc_uf_h

END MODULE pint_normalmode

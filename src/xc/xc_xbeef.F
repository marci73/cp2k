!--------------------------------------------------------------------------------------------------!
!   CP2K: A general program to perform molecular dynamics simulations                              !
!   Copyright 2000-2025 CP2K developers group <https://cp2k.org>                                   !
!                                                                                                  !
!   SPDX-License-Identifier: GPL-2.0-or-later                                                      !
!--------------------------------------------------------------------------------------------------!

! **************************************************************************************************
!> \brief calculates the Exchange contribution in the BEEF-vdW functional
!         (Norskov Group)
!> \par History
!>      02.2014 created based on xc_xbecke88.F [rkoitz]
!> \author rkoitz
! **************************************************************************************************
MODULE xc_xbeef

   USE bibliography,                    ONLY: Wellendorff2012,&
                                              cite_reference
   USE cp_array_utils,                  ONLY: cp_3d_r_cp_type
   USE input_section_types,             ONLY: section_vals_type,&
                                              section_vals_val_get
   USE kinds,                           ONLY: dp
   USE mathconstants,                   ONLY: pi
   USE xc_derivative_desc,              ONLY: deriv_norm_drho,&
                                              deriv_norm_drhoa,&
                                              deriv_norm_drhob,&
                                              deriv_rho,&
                                              deriv_rhoa,&
                                              deriv_rhob
   USE xc_derivative_set_types,         ONLY: xc_derivative_set_type,&
                                              xc_dset_get_derivative
   USE xc_derivative_types,             ONLY: xc_derivative_get,&
                                              xc_derivative_type
   USE xc_rho_cflags_types,             ONLY: xc_rho_cflags_type
   USE xc_rho_set_types,                ONLY: xc_rho_set_get,&
                                              xc_rho_set_type
#include "../base/base_uses.f90"

   IMPLICIT NONE
   PRIVATE

   LOGICAL, PRIVATE, PARAMETER :: debug_this_module = .TRUE.
   CHARACTER(len=*), PARAMETER, PRIVATE :: moduleN = 'xc_xbeef'

   PUBLIC :: xbeef_lda_info, xbeef_lsd_info, xbeef_lda_eval, xbeef_lsd_eval

   !for beef functional pulled out of GPAW source, Feb 2014
   REAL(kind=dp), PARAMETER :: a(0:29) = (/1.516501714304992365356_dp, 0.441353209874497942611_dp, -0.091821352411060291887_dp, &
                                           -0.023527543314744041314_dp, 0.034188284548603550816_dp, 0.002411870075717384172_dp, &
                                           -0.014163813515916020766_dp, 0.000697589558149178113_dp, 0.009859205136982565273_dp, &
                                           -0.006737855050935187551_dp, -0.001573330824338589097_dp, 0.005036146253345903309_dp, &
                                           -0.002569472452841069059_dp, -0.000987495397608761146_dp, 0.002033722894696920677_dp, &
                                           -0.000801871884834044583_dp, -0.000668807872347525591_dp, 0.001030936331268264214_dp, &
                                           -0.000367383865990214423_dp, -0.000421363539352619543_dp, 0.000576160799160517858_dp, &
                                           -0.000083465037349510408_dp, -0.000445844758523195788_dp, 0.000460129009232047457_dp, &
                                           -0.000005231775398304339_dp, -0.000423957047149510404_dp, 0.000375019067938866537_dp, &
                                           0.000021149381251344578_dp, -0.000190491156503997170_dp, 0.000073843624209823442_dp/)
CONTAINS

! **************************************************************************************************
!> \brief return various information on the functional
!> \param reference string with the reference of the actual functional
!> \param shortform string with the shortform of the functional name
!> \param needs the components needed by this functional are set to
!>        true (does not set the unneeded components to false)
!> \param max_deriv ...
!> \par History
!>      02.2014 created
!> \author rkoitz
! **************************************************************************************************

   SUBROUTINE xbeef_lda_info(reference, shortform, needs, max_deriv)
      CHARACTER(LEN=*), INTENT(OUT), OPTIONAL            :: reference, shortform
      TYPE(xc_rho_cflags_type), INTENT(inout), OPTIONAL  :: needs
      INTEGER, INTENT(out), OPTIONAL                     :: max_deriv

      IF (PRESENT(reference)) THEN
         reference = "Wellendorff, J. et al., Phys. Rev. B 85, 235149 (2012) {LDA}"
      END IF
      IF (PRESENT(shortform)) THEN
         shortform = "Exchange Contribution to BEEF-vdW Functional (Wellendorff, 2012) {LDA}"
      END IF
      IF (PRESENT(needs)) THEN
         needs%rho = .TRUE.
         needs%rho_1_3 = .TRUE.
         needs%norm_drho = .TRUE.
      END IF
      IF (PRESENT(max_deriv)) max_deriv = 1

   END SUBROUTINE xbeef_lda_info

! **************************************************************************************************
!> \brief return various information on the functional
!> \param reference string with the reference of the actual functional
!> \param shortform string with the shortform of the functional name
!> \param needs the components needed by this functional are set to
!>        true (does not set the unneeded components to false)
!> \param max_deriv ...
!> \par History
!>      02.2014 created
!> \author rkoitz
! **************************************************************************************************
   SUBROUTINE xbeef_lsd_info(reference, shortform, needs, max_deriv)
      CHARACTER(LEN=*), INTENT(OUT), OPTIONAL            :: reference, shortform
      TYPE(xc_rho_cflags_type), INTENT(inout), OPTIONAL  :: needs
      INTEGER, INTENT(out), OPTIONAL                     :: max_deriv

      IF (PRESENT(reference)) THEN
         reference = "Wellendorff, J. et al., Phys. Rev. B 85, 235149 (2012) {LSD}"
      END IF
      IF (PRESENT(shortform)) THEN
         shortform = "Exchange Contribution to BEEF-vdW Functional (Wellendorff, 2012) {LSD}"
      END IF
      IF (PRESENT(needs)) THEN
         needs%rho_spin = .TRUE.
         needs%rho_spin_1_3 = .TRUE.
         needs%norm_drho_spin = .TRUE.
      END IF
      IF (PRESENT(max_deriv)) max_deriv = 1

   END SUBROUTINE xbeef_lsd_info

! **************************************************************************************************
!> \brief evaluates the beef exchange functional for lda
!> \param rho_set the density where you want to evaluate the functional
!> \param deriv_set place where to store the functional derivatives (they are
!>        added to the derivatives)
!> \param grad_deriv degree of the derivative that should be evaluated,
!>        if positive all the derivatives up to the given degree are evaluated,
!>        if negative only the given degree is calculated
!> \param xbeef_params input parameters (scaling)
!> \par History
!>      02.2014 created
!> \author rkoitz
! **************************************************************************************************
   SUBROUTINE xbeef_lda_eval(rho_set, deriv_set, grad_deriv, xbeef_params)
      TYPE(xc_rho_set_type), INTENT(IN)                  :: rho_set
      TYPE(xc_derivative_set_type), INTENT(IN)           :: deriv_set
      INTEGER, INTENT(in)                                :: grad_deriv
      TYPE(section_vals_type), POINTER                   :: xbeef_params

      CHARACTER(len=*), PARAMETER                        :: routineN = 'xbeef_lda_eval'

      INTEGER                                            :: handle, npoints
      INTEGER, DIMENSION(2, 3)                           :: bo
      REAL(kind=dp)                                      :: epsilon_rho, sx
      REAL(kind=dp), CONTIGUOUS, DIMENSION(:, :, :), &
         POINTER                                         :: dummy, e_0, e_ndrho, e_rho, norm_drho, &
                                                            rho, rho_1_3
      TYPE(xc_derivative_type), POINTER                  :: deriv

      CALL timeset(routineN, handle)

      CALL section_vals_val_get(xbeef_params, "scale_x", r_val=sx)

      CALL cite_reference(Wellendorff2012)

      CALL xc_rho_set_get(rho_set, rho_1_3=rho_1_3, rho=rho, &
                          norm_drho=norm_drho, local_bounds=bo, rho_cutoff=epsilon_rho)
      npoints = (bo(2, 1) - bo(1, 1) + 1)*(bo(2, 2) - bo(1, 2) + 1)*(bo(2, 3) - bo(1, 3) + 1)

      dummy => rho

      e_0 => dummy
      e_rho => dummy
      e_ndrho => dummy

      IF (grad_deriv >= 0) THEN
         deriv => xc_dset_get_derivative(deriv_set, [INTEGER::], &
                                         allocate_deriv=.TRUE.)
         CALL xc_derivative_get(deriv, deriv_data=e_0)
      END IF
      IF (grad_deriv >= 1 .OR. grad_deriv == -1) THEN
         deriv => xc_dset_get_derivative(deriv_set, [deriv_rho], &
                                         allocate_deriv=.TRUE.)
         CALL xc_derivative_get(deriv, deriv_data=e_rho)
         deriv => xc_dset_get_derivative(deriv_set, [deriv_norm_drho], &
                                         allocate_deriv=.TRUE.)
         CALL xc_derivative_get(deriv, deriv_data=e_ndrho)
      END IF
      IF (grad_deriv > 1 .OR. grad_deriv < -1) THEN
         CPABORT("derivatives greater than 1 not implemented")
      END IF

!$OMP     PARALLEL DEFAULT(NONE) &
!$OMP              SHARED(rho, rho_1_3, norm_drho, e_0, e_rho) &
!$OMP              SHARED(e_ndrho) &
!$OMP              SHARED( grad_deriv, npoints) &
!$OMP              SHARED(epsilon_rho,sx)
      CALL xbeef_lda_calc(rho=rho, rho_1_3=rho_1_3, norm_drho=norm_drho, &
                          e_0=e_0, e_rho=e_rho, e_ndrho=e_ndrho, &
                          grad_deriv=grad_deriv, &
                          npoints=npoints, epsilon_rho=epsilon_rho, sx=sx)
!$OMP     END PARALLEL

      CALL timestop(handle)
   END SUBROUTINE xbeef_lda_eval

! **************************************************************************************************
!> \brief evaluates the beef exchange functional for lda
!> \param rho the density where you want to evaluate the functional
!> \param rho_1_3 ...
!> \param norm_drho ...
!> \param e_0 ...
!> \param e_rho ...
!> \param e_ndrho ...
!> \param grad_deriv degree of the derivative that should be evaluated,
!>        if positive all the derivatives up to the given degree are evaluated,
!>        if negative only the given degree is calculated
!> \param npoints ...
!> \param epsilon_rho ...
!> \param sx scaling-parameter for exchange
!> \par History
!>      02.2014 created based on xc_xbecke88
!> \author rkoitz
! **************************************************************************************************
   SUBROUTINE xbeef_lda_calc(rho, rho_1_3, norm_drho, &
                             e_0, e_rho, e_ndrho, &
                             grad_deriv, npoints, epsilon_rho, sx)
      INTEGER, INTENT(in)                                :: npoints, grad_deriv
      REAL(kind=dp), DIMENSION(1:npoints), INTENT(inout) :: e_ndrho, e_rho, e_0
      REAL(kind=dp), DIMENSION(1:npoints), INTENT(in)    :: norm_drho, rho_1_3, rho
      REAL(kind=dp), INTENT(in)                          :: epsilon_rho, sx

      INTEGER, PARAMETER                                 :: m = 30

      INTEGER                                            :: i, ii
      REAL(kind=dp)                                      :: ds_ndrho, ds_rho, dt, e_ueg, e_ueg_drho, &
                                                            epsilon_rho43, k_lda, kf, my_rho, &
                                                            my_rho_1_3, s, s2, t, t3
      REAL(kind=dp), DIMENSION(0:29)                     :: de_leg, e_leg

!energies, first and second derivatives from legendre pol

      kf = (3.0_dp*pi**2)**(1.0_dp/3.0_dp) !only constants, without n^1/3
      k_lda = -(2.0_dp/(2.0_dp**(4._dp/3._dp)))*(3.0_dp/2.0_dp)*(3.0_dp/(4.0_dp*pi))**(1.0_dp/3.0_dp)
      !exchange energy density of the uniform electron gas, non spin-polarized

      epsilon_rho43 = epsilon_rho**(4._dp/3._dp)

!$OMP     DO
      DO ii = 1, npoints

         my_rho = rho(ii)

         IF (my_rho > epsilon_rho) THEN
            my_rho_1_3 = rho_1_3(ii)

            e_ueg = k_lda*my_rho*my_rho_1_3
            e_ueg_drho = (4.0_dp/3.0_dp)*k_lda*my_rho_1_3

            t3 = my_rho_1_3*my_rho*2*kf !reduced gradient, denominator

            s = norm_drho(ii)/MAX(t3, epsilon_rho43) !reduced gradient finally
            s2 = s**2
            t = 2.0_dp*s2/(4.0_dp + s2) - 1.0_dp

            IF (grad_deriv >= 0) THEN !asking for pure e evaluation or also derivatives
               e_leg(0) = 1 !first legendre pol
               e_leg(1) = t !second legendre pol
            END IF

            IF ((grad_deriv >= 1) .OR. (grad_deriv == -1)) THEN !asking for first derivative or higher
               de_leg(0) = 0
               de_leg(1) = 1
               dt = 4.0_dp*s/(4.0_dp + s2) - 4.0_dp*s*s2/(4.0_dp + s2)**2
               ds_rho = -(4.0_dp*s)/(3.0_dp*MAX(my_rho, epsilon_rho))
               ds_ndrho = 1.0_dp/(MAX(t3, epsilon_rho43))
            END IF

            DO i = 2, m - 1 !LEGENDRE PART
               e_leg(i) = 2.*(t)*e_leg(i - 1) - e_leg(i - 2) - ((t)*e_leg(i - 1) - e_leg(i - 2))/(REAL(i, KIND=dp))
               !taken from quantum espresso beef library.

               IF (ABS(grad_deriv) >= 1) THEN !first derivative
                  !the zero-derivatives need to be available for the first deriv.
                  de_leg(i) = e_leg(i - 1)*i + de_leg(i - 1)*(t)
               END IF
            END DO

            !NO DERIVATIVE
            IF (grad_deriv >= 0) THEN
               !add the scaled legendre linear combination to e_0
               e_0(ii) = e_0(ii) + SUM(e_leg*a)*e_ueg*sx
            END IF

            !FIRST DERIVATIVE
            IF ((grad_deriv >= 1) .OR. (grad_deriv == -1)) THEN !asking for first derivative or higher
               e_rho(ii) = e_rho(ii) + (SUM(e_leg*a)*e_ueg_drho + SUM(de_leg*a)*dt*ds_rho*e_ueg)*sx
               e_ndrho(ii) = e_ndrho(ii) + (SUM(de_leg*a)*dt*ds_ndrho*e_ueg)*sx
            END IF

         END IF
      END DO

!$OMP    END DO

   END SUBROUTINE xbeef_lda_calc

! **************************************************************************************************
!> \brief evaluates the beef 88 exchange functional for lsd
!> \param rho_set ...
!> \param deriv_set ...
!> \param grad_deriv ...
!> \param xbeef_params ...
!> \par History
!>         2/2014 rkoitz [created based on Becke 88]
!> \author rkoitz
! **************************************************************************************************
   SUBROUTINE xbeef_lsd_eval(rho_set, deriv_set, grad_deriv, xbeef_params)
      TYPE(xc_rho_set_type), INTENT(IN)                  :: rho_set
      TYPE(xc_derivative_set_type), INTENT(IN)           :: deriv_set
      INTEGER, INTENT(in)                                :: grad_deriv
      TYPE(section_vals_type), POINTER                   :: xbeef_params

      CHARACTER(len=*), PARAMETER                        :: routineN = 'xbeef_lsd_eval'

      INTEGER                                            :: handle, i, ispin, npoints
      INTEGER, DIMENSION(2, 3)                           :: bo
      REAL(kind=dp)                                      :: epsilon_rho, sx
      REAL(kind=dp), CONTIGUOUS, DIMENSION(:, :, :), &
         POINTER                                         :: dummy, e_0
      TYPE(cp_3d_r_cp_type), DIMENSION(2)                :: e_ndrho, e_rho, norm_drho, rho, rho_1_3
      TYPE(xc_derivative_type), POINTER                  :: deriv

      CALL timeset(routineN, handle)

      CALL cite_reference(Wellendorff2012)

      NULLIFY (deriv)
      DO i = 1, 2
         NULLIFY (norm_drho(i)%array, rho(i)%array, rho_1_3(i)%array)
      END DO

      CALL section_vals_val_get(xbeef_params, "scale_x", r_val=sx)
      CALL xc_rho_set_get(rho_set, rhoa_1_3=rho_1_3(1)%array, &
                          rhob_1_3=rho_1_3(2)%array, rhoa=rho(1)%array, &
                          rhob=rho(2)%array, norm_drhoa=norm_drho(1)%array, &
                          norm_drhob=norm_drho(2)%array, rho_cutoff=epsilon_rho, &
                          local_bounds=bo)
      npoints = (bo(2, 1) - bo(1, 1) + 1)*(bo(2, 2) - bo(1, 2) + 1)*(bo(2, 3) - bo(1, 3) + 1)

      dummy => rho(1)%array

      e_0 => dummy
      DO i = 1, 2
         e_rho(i)%array => dummy
         e_ndrho(i)%array => dummy
      END DO

      IF (grad_deriv >= 0) THEN
         deriv => xc_dset_get_derivative(deriv_set, [INTEGER::], &
                                         allocate_deriv=.TRUE.)
         CALL xc_derivative_get(deriv, deriv_data=e_0)
      END IF
      IF (grad_deriv >= 1 .OR. grad_deriv == -1) THEN
         deriv => xc_dset_get_derivative(deriv_set, [deriv_rhoa], &
                                         allocate_deriv=.TRUE.)
         CALL xc_derivative_get(deriv, deriv_data=e_rho(1)%array)
         deriv => xc_dset_get_derivative(deriv_set, [deriv_rhob], &
                                         allocate_deriv=.TRUE.)
         CALL xc_derivative_get(deriv, deriv_data=e_rho(2)%array)
         deriv => xc_dset_get_derivative(deriv_set, [deriv_norm_drhoa], &
                                         allocate_deriv=.TRUE.)
         CALL xc_derivative_get(deriv, deriv_data=e_ndrho(1)%array)
         deriv => xc_dset_get_derivative(deriv_set, [deriv_norm_drhob], &
                                         allocate_deriv=.TRUE.)
         CALL xc_derivative_get(deriv, deriv_data=e_ndrho(2)%array)
      END IF
      IF (grad_deriv > 1 .OR. grad_deriv < -1) THEN
         CPABORT("derivatives greater than 1 not implemented")
      END IF

      DO ispin = 1, 2

!$OMP        PARALLEL DEFAULT(NONE) &
!$OMP                 SHARED(rho, ispin, rho_1_3, norm_drho, e_0) &
!$OMP                 SHARED(e_rho, e_ndrho) &
!$OMP                 SHARED(grad_deriv, npoints) &
!$OMP                 SHARED(epsilon_rho, sx)

         CALL xbeef_lsd_calc( &
            rho_spin=rho(ispin)%array, &
            rho_1_3_spin=rho_1_3(ispin)%array, &
            norm_drho_spin=norm_drho(ispin)%array, &
            e_0=e_0, e_rho_spin=e_rho(ispin)%array, &
            e_ndrho_spin=e_ndrho(ispin)%array, &
            grad_deriv=grad_deriv, npoints=npoints, &
            epsilon_rho=epsilon_rho, sx=sx)

!$OMP        END PARALLEL

      END DO

      CALL timestop(handle)

   END SUBROUTINE xbeef_lsd_eval
! **************************************************************************************************
!> \brief low level calculation of the beef exchange functional for lsd
!> \param rho_spin alpha or beta spin density
!> \param rho_1_3_spin rho_spin**(1./3.)
!> \param norm_drho_spin || grad rho_spin ||
!> \param e_0 adds to it the local value of the functional
!> \param e_rho_spin e_*_spin: derivative of the functional wrt. to the variables
!>        named where the * is. Everything wrt. to the spin of the arguments.
!> \param e_ndrho_spin ...
!> \param grad_deriv ...
!> \param npoints ...
!> \param epsilon_rho ...
!> \param sx scaling-parameter for exchange
!> \par History
!>      02.2014 created based on Becke88
!> \author rkoitz
! **************************************************************************************************
   SUBROUTINE xbeef_lsd_calc(rho_spin, rho_1_3_spin, norm_drho_spin, e_0, &
                             e_rho_spin, e_ndrho_spin, grad_deriv, npoints, epsilon_rho, sx)
      REAL(kind=dp), DIMENSION(*), INTENT(in)            :: rho_spin, rho_1_3_spin, norm_drho_spin
      REAL(kind=dp), DIMENSION(*), INTENT(inout)         :: e_0, e_rho_spin, e_ndrho_spin
      INTEGER, INTENT(in)                                :: grad_deriv, npoints
      REAL(kind=dp), INTENT(in)                          :: epsilon_rho, sx

      INTEGER, PARAMETER                                 :: m = 30

      INTEGER                                            :: i, ii
      REAL(kind=dp)                                      :: ds_ndrho, ds_rho, dt, e_ueg, e_ueg_drho, &
                                                            epsilon_rho43, k_lsd, kf, &
                                                            my_epsilon_rho, my_rho, my_rho_1_3, s, &
                                                            s2, t, t3
      REAL(kind=dp), DIMENSION(0:29)                     :: de_leg, e_leg

!energies and first derivatives from legendre pol

      kf = (3.0_dp*pi**2)**(1.0_dp/3.0_dp) !only constants, without n^1/3
      k_lsd = (3.0_dp/2.0_dp)*(3.0_dp/(4.0_dp*pi))**(1.0_dp/3.0_dp)
      !exchange energy density of the uniform electron gas, spin-polarized

      my_epsilon_rho = 0.5_dp*epsilon_rho
      epsilon_rho43 = my_epsilon_rho**(4._dp/3._dp)

!$OMP     DO
      DO ii = 1, npoints
         my_rho = rho_spin(ii)

         IF (my_rho > epsilon_rho) THEN
            my_rho_1_3 = rho_1_3_spin(ii)

            e_ueg = k_lsd*my_rho*my_rho_1_3
            e_ueg_drho = (4.0_dp/3.0_dp)*k_lsd*my_rho_1_3

            t3 = my_rho_1_3*my_rho*2*kf !reduced gradient, denominator

            s = norm_drho_spin(ii)/MAX(t3, epsilon_rho43) !reduced gradient finally
            s2 = s**2
            t = 2.0_dp*s**2/(4.0_dp + s**2) - 1.0_dp

            IF (grad_deriv >= 0) THEN !asking for pure e evaluation or also derivatives
               e_leg(0) = 1 !first legendre pol
               e_leg(1) = t !second legendre pol
            END IF

            IF ((grad_deriv >= 1) .OR. (grad_deriv == -1)) THEN !asking for first derivative or higher
               de_leg(0) = 0
               de_leg(1) = 1
               dt = 4.0_dp*s/(4.0_dp + s2) - 4.0_dp*s*s2/(4.0_dp + s2)**2
               ds_rho = -(4.0_dp*s)/(3.0_dp*MAX(my_rho, epsilon_rho))
               ds_ndrho = 1.0_dp/(MAX(t3, epsilon_rho43))
            END IF

            DO i = 2, m - 1 !LEGENDRE PART
               e_leg(i) = 2.*(t)*e_leg(i - 1) - e_leg(i - 2) - ((t)*e_leg(i - 1) - e_leg(i - 2))/(REAL(i, KIND=dp))
               !taken from quantum espresso beef library.

               IF (ABS(grad_deriv) >= 1) THEN !first derivative
                  !the zero-derivatives need to be available for the first deriv.
                  de_leg(i) = e_leg(i - 1)*i + de_leg(i - 1)*(t)
               END IF

            END DO

            !NO DERIVATIVE
            IF (grad_deriv >= 0) THEN
               !add the scaled legendre linear combination to e_0
               e_0(ii) = e_0(ii) + SUM(e_leg*a)*e_ueg*sx
            END IF

            !FIRST DERIVATIVE
            IF ((grad_deriv >= 1) .OR. (grad_deriv == -1)) THEN !asking for first derivative or higher
               e_rho_spin(ii) = e_rho_spin(ii) + (SUM(e_leg*a)*e_ueg_drho + SUM(de_leg*a)*dt*ds_rho*e_ueg)*sx
               e_ndrho_spin(ii) = e_ndrho_spin(ii) + (SUM(de_leg*a)*dt*ds_ndrho*e_ueg)*sx
            END IF
         END IF
      END DO
!$OMP   END DO

   END SUBROUTINE xbeef_lsd_calc

END MODULE xc_xbeef


! Copyright (C) 2010-2015 Keith Bennett <K.Bennett@warwick.ac.uk>
! Copyright (C) 2009      Chris Brady <C.S.Brady@warwick.ac.uk>
!
! This program is free software: you can redistribute it and/or modify
! it under the terms of the GNU General Public License as published by
! the Free Software Foundation, either version 3 of the License, or
! (at your option) any later version.
!
! This program is distributed in the hope that it will be useful,
! but WITHOUT ANY WARRANTY; without even the implied warranty of
! MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
! GNU General Public License for more details.
!
! You should have received a copy of the GNU General Public License
! along with this program.  If not, see <http://www.gnu.org/licenses/>.

MODULE fields

  USE boundary

  IMPLICIT NONE

  INTEGER :: field_order
  REAL(num) :: hdt, fac
  REAL(num) :: hdtx, hdty, hdtz
  REAL(num) :: cnx, cny, cnz
  REAL(num) :: alphax, alphay, alphaz
  REAL(num) :: betaxy, betayx, betazx, betaxz, betazy, betayz
  REAL(num) :: deltax, deltay, deltaz
  REAL(num) :: gammax, gammay, gammaz

CONTAINS

  SUBROUTINE set_field_order(order)

    INTEGER, INTENT(IN) :: order

    field_order = order
    fng = field_order / 2

    IF (field_order == 2) THEN
      cfl = 1.0_num
    ELSE IF (field_order == 4) THEN
      cfl = 6.0_num / 7.0_num
    ELSE
      cfl = 120.0_num / 149.0_num
    ENDIF

  END SUBROUTINE set_field_order



  SUBROUTINE set_maxwell_solver

    REAL(num) :: delta, dx_cdt
    REAL(num) :: c1, c2, c3, cx1, cx2

    IF (maxwell_solver == c_maxwell_solver_lehe) THEN
      ! R. Lehe et al., Phys. Rev. ST Accel. Beams 16, 021301 (2013)
      dx_cdt = dx / (c * dt)
      betaxy = 0.125_num * (dx / dy)**2
      betaxz = 0.125_num * (dx / dz)**2
      betayx = 0.125_num
      betazx = 0.125_num
      betazy = 0.0_num
      betayz = 0.0_num
      deltax = 0.25_num * (1.0_num - dx_cdt**2 * SIN(0.5_num * pi / dx_cdt)**2)
      deltay = 0.0_num
      deltaz = 0.0_num
      gammax = 0.0_num
      gammay = 0.0_num
      gammaz = 0.0_num
      alphax = 1.0_num - 2.0_num * betaxy - 2.0_num * betaxz - 3.0_num * deltax
      alphay = 1.0_num - 2.0_num * betayx
      alphaz = 1.0_num - 2.0_num * betazx
    ENDIF

    IF (maxwell_solver == c_maxwell_solver_cowan) THEN
      ! Cowan et al., Phys. Rev. ST Accel. Beams 16, 041303 (2013)
      delta = MIN(dx, dy, dz)
      c1 = (delta / dx)**2
      c2 = (delta / dy)**2
      c3 = (delta / dz)**2
      cx1 = 1.0_num / (c1 * c2 + c2 * c3 + c1 * c3)
      cx2 = 1.0_num - c1 * c2 * c3 * cx1

      betayx = 0.125_num * c1 * cx2
      betaxy = 0.125_num * c2 * cx2
      betaxz = 0.125_num * c3 * cx2
      betazx = betayx
      betazy = betaxy
      betayz = betaxz
      deltax = 0.0_num
      deltay = 0.0_num
      deltaz = 0.0_num
      gammax = c2 * c3 * (0.0625_num - 0.125_num * c2 * c3 * cx1)
      gammay = c1 * c3 * (0.0625_num - 0.125_num * c1 * c3 * cx1)
      gammaz = c1 * c2 * (0.0625_num - 0.125_num * c1 * c2 * cx1)
      alphax = 1.0_num - 2.0_num * betaxy - 2.0_num * betaxz - 4.0_num * gammax
      alphay = 1.0_num - 2.0_num * betayx - 2.0_num * betayz - 4.0_num * gammay
      alphaz = 1.0_num - 2.0_num * betazx - 2.0_num * betazy - 4.0_num * gammaz
    ENDIF

    IF (maxwell_solver == c_maxwell_solver_pukhov) THEN
      ! A. Pukhov, Journal of Plasma Physics 61, 425-433 (1999)
      delta = MIN(dx, dy, dz)

      betayx = 0.125_num * (delta / dx)**2
      betaxy = 0.125_num * (delta / dy)**2
      betaxz = 0.125_num * (delta / dz)**2
      betazx = betayx
      betazy = betaxy
      betayz = betaxz
      deltax = 0.0_num
      deltay = 0.0_num
      deltaz = 0.0_num
      gammax = 0.0_num
      gammay = 0.0_num
      gammaz = 0.0_num
      alphax = 1.0_num - 2.0_num * betaxy - 2.0_num * betaxz
      alphay = 1.0_num - 2.0_num * betayx - 2.0_num * betayz
      alphaz = 1.0_num - 2.0_num * betazx - 2.0_num * betazy
    ENDIF

  END SUBROUTINE set_maxwell_solver



  SUBROUTINE update_e_field

    INTEGER :: ix, iy, iz
    REAL(num) :: cpml_x, cpml_y, cpml_z
    REAL(num) :: c1, c2, c3
    REAL(num) :: cx1, cx2, cx3
    REAL(num) :: cy1, cy2, cy3
    REAL(num) :: cz1, cz2, cz3

    IF (cpml_boundaries) THEN
      cpml_x = cnx
      cpml_y = cny
      cpml_z = cnz

      IF (field_order == 2) THEN
        DO iz = 1, nz
          cpml_z = cnz / cpml_kappa_ez(iz)
          DO iy = 1, ny
            cpml_y = cny / cpml_kappa_ey(iy)
            DO ix = 1, nx
              cpml_x = cnx / cpml_kappa_ex(ix)

              ex(ix, iy, iz) = ex(ix, iy, iz) &
                  + cpml_y * (bz(ix  , iy  , iz  ) - bz(ix  , iy-1, iz  )) &
                  - cpml_z * (by(ix  , iy  , iz  ) - by(ix  , iy  , iz-1)) &
                  - fac * jx(ix, iy, iz)

              ey(ix, iy, iz) = ey(ix, iy, iz) &
                  + cpml_z * (bx(ix  , iy  , iz  ) - bx(ix  , iy  , iz-1)) &
                  - cpml_x * (bz(ix  , iy  , iz  ) - bz(ix-1, iy  , iz  )) &
                  - fac * jy(ix, iy, iz)

              ez(ix, iy, iz) = ez(ix, iy, iz) &
                  + cpml_x * (by(ix  , iy  , iz  ) - by(ix-1, iy  , iz  )) &
                  - cpml_y * (bx(ix  , iy  , iz  ) - bx(ix  , iy-1, iz  )) &
                  - fac * jz(ix, iy, iz)
            ENDDO
          ENDDO
        ENDDO
      ELSE IF (field_order == 4) THEN
        c1 = 9.0_num / 8.0_num
        c2 = -1.0_num / 24.0_num

        DO iz = 1, nz
          cpml_z = cnz / cpml_kappa_ez(iz)
          cz1 = c1 * cpml_z
          cz2 = c2 * cpml_z
          DO iy = 1, ny
            cpml_y = cny / cpml_kappa_ey(iy)
            cy1 = c1 * cpml_y
            cy2 = c2 * cpml_y
            DO ix = 1, nx
              cpml_x = cnx / cpml_kappa_ex(ix)
              cx1 = c1 * cpml_x
              cx2 = c2 * cpml_x

              ex(ix, iy, iz) = ex(ix, iy, iz) &
                  + cy1 * (bz(ix  , iy  , iz  ) - bz(ix  , iy-1, iz  )) &
                  + cy2 * (bz(ix  , iy+1, iz  ) - bz(ix  , iy-2, iz  )) &
                  - cz1 * (by(ix  , iy  , iz  ) - by(ix  , iy  , iz-1)) &
                  - cz2 * (by(ix  , iy  , iz+1) - by(ix  , iy  , iz-2)) &
                  - fac * jx(ix, iy, iz)

              ey(ix, iy, iz) = ey(ix, iy, iz) &
                  + cz1 * (bx(ix  , iy  , iz  ) - bx(ix  , iy  , iz-1)) &
                  + cz2 * (bx(ix  , iy  , iz+1) - bx(ix  , iy  , iz-2)) &
                  - cx1 * (bz(ix  , iy  , iz  ) - bz(ix-1, iy  , iz  )) &
                  - cx2 * (bz(ix+1, iy  , iz  ) - bz(ix-2, iy  , iz  )) &
                  - fac * jy(ix, iy, iz)

              ez(ix, iy, iz) = ez(ix, iy, iz) &
                  + cx1 * (by(ix  , iy  , iz  ) - by(ix-1, iy  , iz  )) &
                  + cx2 * (by(ix+1, iy  , iz  ) - by(ix-2, iy  , iz  )) &
                  - cy1 * (bx(ix  , iy  , iz  ) - bx(ix  , iy-1, iz  )) &
                  - cy2 * (bx(ix  , iy+1, iz  ) - bx(ix  , iy-2, iz  )) &
                  - fac * jz(ix, iy, iz)
            ENDDO
          ENDDO
        ENDDO
      ELSE
        c1 = 75.0_num / 64.0_num
        c2 = -25.0_num / 384.0_num
        c3 = 3.0_num / 640.0_num

        DO iz = 1, nz
          cpml_z = cnz / cpml_kappa_ez(iz)
          cz1 = c1 * cpml_z
          cz2 = c2 * cpml_z
          cz3 = c3 * cpml_z
          DO iy = 1, ny
            cpml_y = cny / cpml_kappa_ey(iy)
            cy1 = c1 * cpml_y
            cy2 = c2 * cpml_y
            cy3 = c3 * cpml_y
            DO ix = 1, nx
              cpml_x = cnx / cpml_kappa_ex(ix)
              cx1 = c1 * cpml_x
              cx2 = c2 * cpml_x
              cx3 = c3 * cpml_x

              ex(ix, iy, iz) = ex(ix, iy, iz) &
                  + cy1 * (bz(ix  , iy  , iz  ) - bz(ix  , iy-1, iz  )) &
                  + cy2 * (bz(ix  , iy+1, iz  ) - bz(ix  , iy-2, iz  )) &
                  + cy3 * (bz(ix  , iy+2, iz  ) - bz(ix  , iy-3, iz  )) &
                  - cz1 * (by(ix  , iy  , iz  ) - by(ix  , iy  , iz-1)) &
                  - cz2 * (by(ix  , iy  , iz+1) - by(ix  , iy  , iz-2)) &
                  - cz3 * (by(ix  , iy  , iz+2) - by(ix  , iy  , iz-3)) &
                  - fac * jx(ix, iy, iz)

              ey(ix, iy, iz) = ey(ix, iy, iz) &
                  + cz1 * (bx(ix  , iy  , iz  ) - bx(ix  , iy  , iz-1)) &
                  + cz2 * (bx(ix  , iy  , iz+1) - bx(ix  , iy  , iz-2)) &
                  + cz3 * (bx(ix  , iy  , iz+2) - bx(ix  , iy  , iz-3)) &
                  - cx1 * (bz(ix  , iy  , iz  ) - bz(ix-1, iy  , iz  )) &
                  - cx2 * (bz(ix+1, iy  , iz  ) - bz(ix-2, iy  , iz  )) &
                  - cx3 * (bz(ix+2, iy  , iz  ) - bz(ix-3, iy  , iz  )) &
                  - fac * jy(ix, iy, iz)

              ez(ix, iy, iz) = ez(ix, iy, iz) &
                  + cx1 * (by(ix  , iy  , iz  ) - by(ix-1, iy  , iz  )) &
                  + cx2 * (by(ix+1, iy  , iz  ) - by(ix-2, iy  , iz  )) &
                  + cx3 * (by(ix+2, iy  , iz  ) - by(ix-3, iy  , iz  )) &
                  - cy1 * (bx(ix  , iy  , iz  ) - bx(ix  , iy-1, iz  )) &
                  - cy2 * (bx(ix  , iy+1, iz  ) - bx(ix  , iy-2, iz  )) &
                  - cy3 * (bx(ix  , iy+2, iz  ) - bx(ix  , iy-3, iz  )) &
                  - fac * jz(ix, iy, iz)
            ENDDO
          ENDDO
        ENDDO
      ENDIF

      CALL cpml_advance_e_currents(hdt)
    ELSE
      IF (field_order == 2) THEN
        DO iz = 1, nz
          DO iy = 1, ny
            DO ix = 1, nx

              ex(ix, iy, iz) = ex(ix, iy, iz) &
                  + cny * (bz(ix  , iy  , iz  ) - bz(ix  , iy-1, iz  )) &
                  - cnz * (by(ix  , iy  , iz  ) - by(ix  , iy  , iz-1)) &
                  - fac * jx(ix, iy, iz)

              ey(ix, iy, iz) = ey(ix, iy, iz) &
                  + cnz * (bx(ix  , iy  , iz  ) - bx(ix  , iy  , iz-1)) &
                  - cnx * (bz(ix  , iy  , iz  ) - bz(ix-1, iy  , iz  )) &
                  - fac * jy(ix, iy, iz)

              ez(ix, iy, iz) = ez(ix, iy, iz) &
                  + cnx * (by(ix  , iy  , iz  ) - by(ix-1, iy  , iz  )) &
                  - cny * (bx(ix  , iy  , iz  ) - bx(ix  , iy-1, iz  )) &
                  - fac * jz(ix, iy, iz)
            ENDDO
          ENDDO
        ENDDO
      ELSE IF (field_order == 4) THEN
        c1 = 9.0_num / 8.0_num
        c2 = -1.0_num / 24.0_num

        DO iz = 1, nz
          cz1 = c1 * cnz
          cz2 = c2 * cnz
          DO iy = 1, ny
            cy1 = c1 * cny
            cy2 = c2 * cny
            DO ix = 1, nx
              cx1 = c1 * cnx
              cx2 = c2 * cnx

              ex(ix, iy, iz) = ex(ix, iy, iz) &
                  + cy1 * (bz(ix  , iy  , iz  ) - bz(ix  , iy-1, iz  )) &
                  + cy2 * (bz(ix  , iy+1, iz  ) - bz(ix  , iy-2, iz  )) &
                  - cz1 * (by(ix  , iy  , iz  ) - by(ix  , iy  , iz-1)) &
                  - cz2 * (by(ix  , iy  , iz+1) - by(ix  , iy  , iz-2)) &
                  - fac * jx(ix, iy, iz)

              ey(ix, iy, iz) = ey(ix, iy, iz) &
                  + cz1 * (bx(ix  , iy  , iz  ) - bx(ix  , iy  , iz-1)) &
                  + cz2 * (bx(ix  , iy  , iz+1) - bx(ix  , iy  , iz-2)) &
                  - cx1 * (bz(ix  , iy  , iz  ) - bz(ix-1, iy  , iz  )) &
                  - cx2 * (bz(ix+1, iy  , iz  ) - bz(ix-2, iy  , iz  )) &
                  - fac * jy(ix, iy, iz)

              ez(ix, iy, iz) = ez(ix, iy, iz) &
                  + cx1 * (by(ix  , iy  , iz  ) - by(ix-1, iy  , iz  )) &
                  + cx2 * (by(ix+1, iy  , iz  ) - by(ix-2, iy  , iz  )) &
                  - cy1 * (bx(ix  , iy  , iz  ) - bx(ix  , iy-1, iz  )) &
                  - cy2 * (bx(ix  , iy+1, iz  ) - bx(ix  , iy-2, iz  )) &
                  - fac * jz(ix, iy, iz)
            ENDDO
          ENDDO
        ENDDO
      ELSE
        c1 = 75.0_num / 64.0_num
        c2 = -25.0_num / 384.0_num
        c3 = 3.0_num / 640.0_num

        DO iz = 1, nz
          cz1 = c1 * cnz
          cz2 = c2 * cnz
          cz3 = c3 * cnz
          DO iy = 1, ny
            cy1 = c1 * cny
            cy2 = c2 * cny
            cy3 = c3 * cny
            DO ix = 1, nx
              cx1 = c1 * cnx
              cx2 = c2 * cnx
              cx3 = c3 * cnx

              ex(ix, iy, iz) = ex(ix, iy, iz) &
                  + cy1 * (bz(ix  , iy  , iz  ) - bz(ix  , iy-1, iz  )) &
                  + cy2 * (bz(ix  , iy+1, iz  ) - bz(ix  , iy-2, iz  )) &
                  + cy3 * (bz(ix  , iy+2, iz  ) - bz(ix  , iy-3, iz  )) &
                  - cz1 * (by(ix  , iy  , iz  ) - by(ix  , iy  , iz-1)) &
                  - cz2 * (by(ix  , iy  , iz+1) - by(ix  , iy  , iz-2)) &
                  - cz3 * (by(ix  , iy  , iz+2) - by(ix  , iy  , iz-3)) &
                  - fac * jx(ix, iy, iz)

              ey(ix, iy, iz) = ey(ix, iy, iz) &
                  + cz1 * (bx(ix  , iy  , iz  ) - bx(ix  , iy  , iz-1)) &
                  + cz2 * (bx(ix  , iy  , iz+1) - bx(ix  , iy  , iz-2)) &
                  + cz3 * (bx(ix  , iy  , iz+2) - bx(ix  , iy  , iz-3)) &
                  - cx1 * (bz(ix  , iy  , iz  ) - bz(ix-1, iy  , iz  )) &
                  - cx2 * (bz(ix+1, iy  , iz  ) - bz(ix-2, iy  , iz  )) &
                  - cx3 * (bz(ix+2, iy  , iz  ) - bz(ix-3, iy  , iz  )) &
                  - fac * jy(ix, iy, iz)

              ez(ix, iy, iz) = ez(ix, iy, iz) &
                  + cx1 * (by(ix  , iy  , iz  ) - by(ix-1, iy  , iz  )) &
                  + cx2 * (by(ix+1, iy  , iz  ) - by(ix-2, iy  , iz  )) &
                  + cx3 * (by(ix+2, iy  , iz  ) - by(ix-3, iy  , iz  )) &
                  - cy1 * (bx(ix  , iy  , iz  ) - bx(ix  , iy-1, iz  )) &
                  - cy2 * (bx(ix  , iy+1, iz  ) - bx(ix  , iy-2, iz  )) &
                  - cy3 * (bx(ix  , iy+2, iz  ) - bx(ix  , iy-3, iz  )) &
                  - fac * jz(ix, iy, iz)
            ENDDO
          ENDDO
        ENDDO
      ENDIF
    ENDIF

  END SUBROUTINE update_e_field



  SUBROUTINE update_b_field

    INTEGER :: ix, iy, iz
    REAL(num) :: cpml_x, cpml_y, cpml_z
    REAL(num) :: c1, c2, c3
    REAL(num) :: cx1, cx2, cx3
    REAL(num) :: cy1, cy2, cy3
    REAL(num) :: cz1, cz2, cz3

    IF (cpml_boundaries) THEN
      cpml_x = hdtx
      cpml_y = hdty
      cpml_z = hdtz

      IF (field_order == 2) THEN
        IF (maxwell_solver == c_maxwell_solver_yee) THEN
          DO iz = 1, nz
            cpml_z = hdtz / cpml_kappa_bz(iz)
            DO iy = 1, ny
              cpml_y = hdty / cpml_kappa_by(iy)
              DO ix = 1, nx
                cpml_x = hdtx / cpml_kappa_bx(ix)

                bx(ix, iy, iz) = bx(ix, iy, iz) &
                    - cpml_y * (ez(ix  , iy+1, iz  ) - ez(ix  , iy  , iz  )) &
                    + cpml_z * (ey(ix  , iy  , iz+1) - ey(ix  , iy  , iz  ))

                by(ix, iy, iz) = by(ix, iy, iz) &
                    - cpml_z * (ex(ix  , iy  , iz+1) - ex(ix  , iy  , iz  )) &
                    + cpml_x * (ez(ix+1, iy  , iz  ) - ez(ix  , iy  , iz  ))

                bz(ix, iy, iz) = bz(ix, iy, iz) &
                    - cpml_x * (ey(ix+1, iy  , iz  ) - ey(ix  , iy  , iz  )) &
                    + cpml_y * (ex(ix  , iy+1, iz  ) - ex(ix  , iy  , iz  ))
              ENDDO
            ENDDO
          ENDDO
        ELSE
          DO iz = 1, nz
            cpml_z = hdtz / cpml_kappa_bz(iz)
            DO iy = 1, ny
              cpml_y = hdty / cpml_kappa_by(iy)
              DO ix = 1, nx
                cpml_x = hdtx / cpml_kappa_bx(ix)

                bx(ix, iy, iz) = bx(ix, iy, iz)                                &
                  - cpml_y * (                                                 &
                       alphay * (ez(ix  , iy+1, iz  ) - ez(ix  , iy  , iz  ))  &
                     + betayx * (ez(ix+1, iy+1, iz  ) - ez(ix+1, iy  , iz  )   &
                               + ez(ix-1, iy+1, iz  ) - ez(ix-1, iy  , iz  ))  &
                     + betayz * (ez(ix  , iy+1, iz+1) - ez(ix  , iy  , iz+1)   &
                               + ez(ix  , iy+1, iz-1) - ez(ix  , iy  , iz-1))  &
                     + gammay * (ez(ix+1, iy+1, iz-1) - ez(ix+1, iy  , iz-1)   &
                               + ez(ix-1, iy+1, iz-1) - ez(ix-1, iy  , iz-1)   &
                               + ez(ix+1, iy+1, iz+1) - ez(ix+1, iy  , iz+1)   &
                               + ez(ix-1, iy+1, iz+1) - ez(ix-1, iy  , iz+1))  &
                     + deltay * (ez(ix  , iy+2, iz  ) - ez(ix  , iy-1, iz  ))) &
                  + cpml_z * (                                                 &
                       alphaz * (ey(ix  , iy  , iz+1) - ey(ix  , iy  , iz  ))  &
                     + betazx * (ey(ix+1, iy  , iz+1) - ey(ix+1, iy  , iz  )   &
                               + ey(ix-1, iy  , iz+1) - ey(ix-1, iy  , iz  ))  &
                     + betazy * (ey(ix  , iy+1, iz+1) - ey(ix  , iy+1, iz  )   &
                               + ey(ix  , iy-1, iz+1) - ey(ix  , iy-1, iz  ))  &
                     + gammaz * (ey(ix+1, iy-1, iz+1) - ey(ix+1, iy-1, iz  )   &
                               + ey(ix-1, iy-1, iz+1) - ey(ix-1, iy-1, iz  )   &
                               + ey(ix+1, iy+1, iz+1) - ey(ix+1, iy+1, iz  )   &
                               + ey(ix-1, iy+1, iz+1) - ey(ix-1, iy+1, iz  ))  &
                     + deltaz * (ey(ix  , iy  , iz+2) - ey(ix  , iy  , iz-1)))

                by(ix, iy, iz) = by(ix, iy, iz)                                &
                  - cpml_z * (                                                 &
                       alphaz * (ex(ix  , iy  , iz+1) - ex(ix  , iy  , iz  ))  &
                     + betazx * (ex(ix+1, iy  , iz+1) - ex(ix+1, iy  , iz  )   &
                               + ex(ix-1, iy  , iz+1) - ex(ix-1, iy  , iz  ))  &
                     + betazy * (ex(ix  , iy+1, iz+1) - ex(ix  , iy+1, iz  )   &
                               + ex(ix  , iy-1, iz+1) - ex(ix  , iy-1, iz  ))  &
                     + gammaz * (ex(ix+1, iy-1, iz+1) - ex(ix+1, iy-1, iz  )   &
                               + ex(ix-1, iy-1, iz+1) - ex(ix-1, iy-1, iz  )   &
                               + ex(ix+1, iy+1, iz+1) - ex(ix+1, iy+1, iz  )   &
                               + ex(ix-1, iy+1, iz+1) - ex(ix-1, iy+1, iz  ))  &
                     + deltaz * (ex(ix  , iy  , iz+2) - ex(ix  , iy  , iz-1))) &
                  + cpml_x * (                                                 &
                       alphax * (ez(ix+1, iy  , iz  ) - ez(ix  , iy  , iz  ))  &
                     + betaxy * (ez(ix+1, iy+1, iz  ) - ez(ix  , iy+1, iz  )   &
                               + ez(ix+1, iy-1, iz  ) - ez(ix  , iy-1, iz  ))  &
                     + betaxz * (ez(ix+1, iy  , iz+1) - ez(ix  , iy  , iz+1)   &
                               + ez(ix+1, iy  , iz-1) - ez(ix  , iy  , iz-1))  &
                     + gammax * (ez(ix+1, iy+1, iz-1) - ez(ix  , iy+1, iz-1)   &
                               + ez(ix+1, iy-1, iz-1) - ez(ix  , iy-1, iz-1)   &
                               + ez(ix+1, iy+1, iz+1) - ez(ix  , iy+1, iz+1)   &
                               + ez(ix+1, iy-1, iz+1) - ez(ix  , iy-1, iz+1))  &
                     + deltax * (ez(ix+2, iy  , iz  ) - ez(ix-1, iy  , iz  )))

                bz(ix, iy, iz) = bz(ix, iy, iz)                                &
                  - cpml_x * (                                                 &
                       alphax * (ey(ix+1, iy  , iz  ) - ey(ix  , iy  , iz  ))  &
                     + betaxy * (ey(ix+1, iy+1, iz  ) - ey(ix  , iy+1, iz  )   &
                               + ey(ix+1, iy-1, iz  ) - ey(ix  , iy-1, iz  ))  &
                     + betaxz * (ey(ix+1, iy  , iz+1) - ey(ix  , iy  , iz+1)   &
                               + ey(ix+1, iy  , iz-1) - ey(ix  , iy  , iz-1))  &
                     + gammax * (ey(ix+1, iy+1, iz-1) - ey(ix  , iy+1, iz-1)   &
                               + ey(ix+1, iy-1, iz-1) - ey(ix  , iy-1, iz-1)   &
                               + ey(ix+1, iy+1, iz+1) - ey(ix  , iy+1, iz+1)   &
                               + ey(ix+1, iy-1, iz+1) - ey(ix  , iy-1, iz+1))  &
                     + deltax * (ey(ix+2, iy  , iz  ) - ey(ix-1, iy  , iz  ))) &
                  + cpml_y * (                                                 &
                       alphay * (ex(ix  , iy+1, iz  ) - ex(ix  , iy  , iz  ))  &
                     + betayx * (ex(ix+1, iy+1, iz  ) - ex(ix+1, iy  , iz  )   &
                               + ex(ix-1, iy+1, iz  ) - ex(ix-1, iy  , iz  ))  &
                     + betayz * (ex(ix  , iy+1, iz+1) - ex(ix  , iy  , iz+1)   &
                               + ex(ix  , iy+1, iz-1) - ex(ix  , iy  , iz-1))  &
                     + gammay * (ex(ix+1, iy+1, iz-1) - ex(ix+1, iy  , iz-1)   &
                               + ex(ix-1, iy+1, iz-1) - ex(ix-1, iy  , iz-1)   &
                               + ex(ix+1, iy+1, iz+1) - ex(ix+1, iy  , iz+1)   &
                               + ex(ix-1, iy+1, iz+1) - ex(ix-1, iy  , iz+1))  &
                     + deltay * (ex(ix  , iy+2, iz  ) - ex(ix  , iy-1, iz  )))
              ENDDO
            ENDDO
          ENDDO
        ENDIF
      ELSE IF (field_order == 4) THEN
        c1 = 9.0_num / 8.0_num
        c2 = -1.0_num / 24.0_num

        DO iz = 1, nz
          cpml_z = hdtz / cpml_kappa_bz(iz)
          cz1 = c1 * cpml_z
          cz2 = c2 * cpml_z
          DO iy = 1, ny
            cpml_y = hdty / cpml_kappa_by(iy)
            cy1 = c1 * cpml_y
            cy2 = c2 * cpml_y
            DO ix = 1, nx
              cpml_x = hdtx / cpml_kappa_bx(ix)
              cx1 = c1 * cpml_x
              cx2 = c2 * cpml_x

              bx(ix, iy, iz) = bx(ix, iy, iz) &
                  - cy1 * (ez(ix  , iy+1, iz  ) - ez(ix  , iy  , iz  )) &
                  - cy2 * (ez(ix  , iy+2, iz  ) - ez(ix  , iy-1, iz  )) &
                  + cz1 * (ey(ix  , iy  , iz+1) - ey(ix  , iy  , iz  )) &
                  + cz2 * (ey(ix  , iy  , iz+2) - ey(ix  , iy  , iz-1))

              by(ix, iy, iz) = by(ix, iy, iz) &
                  - cz1 * (ex(ix  , iy  , iz+1) - ex(ix  , iy  , iz  )) &
                  - cz2 * (ex(ix  , iy  , iz+2) - ex(ix  , iy  , iz-1)) &
                  + cx1 * (ez(ix+1, iy  , iz  ) - ez(ix  , iy  , iz  )) &
                  + cx2 * (ez(ix+2, iy  , iz  ) - ez(ix-1, iy  , iz  ))

              bz(ix, iy, iz) = bz(ix, iy, iz) &
                  - cx1 * (ey(ix+1, iy  , iz  ) - ey(ix  , iy  , iz  )) &
                  - cx2 * (ey(ix+2, iy  , iz  ) - ey(ix-1, iy  , iz  )) &
                  + cy1 * (ex(ix  , iy+1, iz  ) - ex(ix  , iy  , iz  )) &
                  + cy2 * (ex(ix  , iy+2, iz  ) - ex(ix  , iy-1, iz  ))
            ENDDO
          ENDDO
        ENDDO
      ELSE
        c1 = 75.0_num / 64.0_num
        c2 = -25.0_num / 384.0_num
        c3 = 3.0_num / 640.0_num

        DO iz = 1, nz
          cpml_z = hdtz / cpml_kappa_bz(iz)
          cz1 = c1 * cpml_z
          cz2 = c2 * cpml_z
          cz3 = c3 * cpml_z
          DO iy = 1, ny
            cpml_y = hdty / cpml_kappa_by(iy)
            cy1 = c1 * cpml_y
            cy2 = c2 * cpml_y
            cy3 = c3 * cpml_y
            DO ix = 1, nx
              cpml_x = hdtx / cpml_kappa_bx(ix)
              cx1 = c1 * cpml_x
              cx2 = c2 * cpml_x
              cx3 = c3 * cpml_x

              bx(ix, iy, iz) = bx(ix, iy, iz) &
                  - cy1 * (ez(ix  , iy+1, iz  ) - ez(ix  , iy  , iz  )) &
                  - cy2 * (ez(ix  , iy+2, iz  ) - ez(ix  , iy-1, iz  )) &
                  - cy3 * (ez(ix  , iy+3, iz  ) - ez(ix  , iy-2, iz  )) &
                  + cz1 * (ey(ix  , iy  , iz+1) - ey(ix  , iy  , iz  )) &
                  + cz2 * (ey(ix  , iy  , iz+2) - ey(ix  , iy  , iz-1)) &
                  + cz3 * (ey(ix  , iy  , iz+3) - ey(ix  , iy  , iz-2))

              by(ix, iy, iz) = by(ix, iy, iz) &
                  - cz1 * (ex(ix  , iy  , iz+1) - ex(ix  , iy  , iz  )) &
                  - cz2 * (ex(ix  , iy  , iz+2) - ex(ix  , iy  , iz-1)) &
                  - cz3 * (ex(ix  , iy  , iz+3) - ex(ix  , iy  , iz-2)) &
                  + cx1 * (ez(ix+1, iy  , iz  ) - ez(ix  , iy  , iz  )) &
                  + cx2 * (ez(ix+2, iy  , iz  ) - ez(ix-1, iy  , iz  )) &
                  + cx3 * (ez(ix+3, iy  , iz  ) - ez(ix-2, iy  , iz  ))

              bz(ix, iy, iz) = bz(ix, iy, iz) &
                  - cx1 * (ey(ix+1, iy  , iz  ) - ey(ix  , iy  , iz  )) &
                  - cx2 * (ey(ix+2, iy  , iz  ) - ey(ix-1, iy  , iz  )) &
                  - cx3 * (ey(ix+3, iy  , iz  ) - ey(ix-2, iy  , iz  )) &
                  + cy1 * (ex(ix  , iy+1, iz  ) - ex(ix  , iy  , iz  )) &
                  + cy2 * (ex(ix  , iy+2, iz  ) - ex(ix  , iy-1, iz  )) &
                  + cy3 * (ex(ix  , iy+3, iz  ) - ex(ix  , iy-2, iz  ))
            ENDDO
          ENDDO
        ENDDO
      ENDIF

      CALL cpml_advance_b_currents(hdt)
    ELSE
      IF (field_order == 2) THEN
        IF (maxwell_solver == c_maxwell_solver_yee) THEN
          DO iz = 1, nz
            DO iy = 1, ny
              DO ix = 1, nx
                bx(ix, iy, iz) = bx(ix, iy, iz) &
                    - hdty * (ez(ix  , iy+1, iz  ) - ez(ix  , iy  , iz  )) &
                    + hdtz * (ey(ix  , iy  , iz+1) - ey(ix  , iy  , iz  ))

                by(ix, iy, iz) = by(ix, iy, iz) &
                    - hdtz * (ex(ix  , iy  , iz+1) - ex(ix  , iy  , iz  )) &
                    + hdtx * (ez(ix+1, iy  , iz  ) - ez(ix  , iy  , iz  ))

                bz(ix, iy, iz) = bz(ix, iy, iz) &
                    - hdtx * (ey(ix+1, iy  , iz  ) - ey(ix  , iy  , iz  )) &
                    + hdty * (ex(ix  , iy+1, iz  ) - ex(ix  , iy  , iz  ))
              ENDDO
            ENDDO
          ENDDO
        ELSE
          DO iz = 1, nz
            DO iy = 1, ny
              DO ix = 1, nx
                bx(ix, iy, iz) = bx(ix, iy, iz) &
                  - hdty * ( &
                       alphay * (ez(ix  , iy+1, iz  ) - ez(ix  , iy  , iz  ))  &
                     + betayx * (ez(ix+1, iy+1, iz  ) - ez(ix+1, iy  , iz  )   &
                               + ez(ix-1, iy+1, iz  ) - ez(ix-1, iy  , iz  ))  &
                     + betayz * (ez(ix  , iy+1, iz+1) - ez(ix  , iy  , iz+1)   &
                               + ez(ix  , iy+1, iz-1) - ez(ix  , iy  , iz-1))  &
                     + gammay * (ez(ix+1, iy+1, iz-1) - ez(ix+1, iy  , iz-1)   &
                               + ez(ix-1, iy+1, iz-1) - ez(ix-1, iy  , iz-1)   &
                               + ez(ix+1, iy+1, iz+1) - ez(ix+1, iy  , iz+1)   &
                               + ez(ix-1, iy+1, iz+1) - ez(ix-1, iy  , iz+1))  &
                     + deltay * (ez(ix  , iy+2, iz  ) - ez(ix  , iy-1, iz  ))) &
                  + hdtz * ( &
                       alphaz * (ey(ix  , iy  , iz+1) - ey(ix  , iy  , iz  ))  &
                     + betazx * (ey(ix+1, iy  , iz+1) - ey(ix+1, iy  , iz  )   &
                               + ey(ix-1, iy  , iz+1) - ey(ix-1, iy  , iz  ))  &
                     + betazy * (ey(ix  , iy+1, iz+1) - ey(ix  , iy+1, iz  )   &
                               + ey(ix  , iy-1, iz+1) - ey(ix  , iy-1, iz  ))  &
                     + gammaz * (ey(ix+1, iy-1, iz+1) - ey(ix+1, iy-1, iz  )   &
                               + ey(ix-1, iy-1, iz+1) - ey(ix-1, iy-1, iz  )   &
                               + ey(ix+1, iy+1, iz+1) - ey(ix+1, iy+1, iz  )   &
                               + ey(ix-1, iy+1, iz+1) - ey(ix-1, iy+1, iz  ))  &
                     + deltaz * (ey(ix  , iy  , iz+2) - ey(ix  , iy  , iz-1)))

                by(ix, iy, iz) = by(ix, iy, iz) &
                  - hdtz * ( &
                       alphaz * (ex(ix  , iy  , iz+1) - ex(ix  , iy  , iz  ))  &
                     + betazx * (ex(ix+1, iy  , iz+1) - ex(ix+1, iy  , iz  )   &
                               + ex(ix-1, iy  , iz+1) - ex(ix-1, iy  , iz  ))  &
                     + betazy * (ex(ix  , iy+1, iz+1) - ex(ix  , iy+1, iz  )   &
                               + ex(ix  , iy-1, iz+1) - ex(ix  , iy-1, iz  ))  &
                     + gammaz * (ex(ix+1, iy-1, iz+1) - ex(ix+1, iy-1, iz  )   &
                               + ex(ix-1, iy-1, iz+1) - ex(ix-1, iy-1, iz  )   &
                               + ex(ix+1, iy+1, iz+1) - ex(ix+1, iy+1, iz  )   &
                               + ex(ix-1, iy+1, iz+1) - ex(ix-1, iy+1, iz  ))  &
                     + deltaz * (ex(ix  , iy  , iz+2) - ex(ix  , iy  , iz-1))) &
                  + hdtx * ( &
                       alphax * (ez(ix+1, iy  , iz  ) - ez(ix  , iy  , iz  ))  &
                     + betaxy * (ez(ix+1, iy+1, iz  ) - ez(ix  , iy+1, iz  )   &
                               + ez(ix+1, iy-1, iz  ) - ez(ix  , iy-1, iz  ))  &
                     + betaxz * (ez(ix+1, iy  , iz+1) - ez(ix  , iy  , iz+1)   &
                               + ez(ix+1, iy  , iz-1) - ez(ix  , iy  , iz-1))  &
                     + gammax * (ez(ix+1, iy+1, iz-1) - ez(ix  , iy+1, iz-1)   &
                               + ez(ix+1, iy-1, iz-1) - ez(ix  , iy-1, iz-1)   &
                               + ez(ix+1, iy+1, iz+1) - ez(ix  , iy+1, iz+1)   &
                               + ez(ix+1, iy-1, iz+1) - ez(ix  , iy-1, iz+1))  &
                     + deltax * (ez(ix+2, iy  , iz  ) - ez(ix-1, iy  , iz  )))

                bz(ix, iy, iz) = bz(ix, iy, iz) &
                  - hdtx * ( &
                       alphax * (ey(ix+1, iy  , iz  ) - ey(ix  , iy  , iz  ))  &
                     + betaxy * (ey(ix+1, iy+1, iz  ) - ey(ix  , iy+1, iz  )   &
                               + ey(ix+1, iy-1, iz  ) - ey(ix  , iy-1, iz  ))  &
                     + betaxz * (ey(ix+1, iy  , iz+1) - ey(ix  , iy  , iz+1)   &
                               + ey(ix+1, iy  , iz-1) - ey(ix  , iy  , iz-1))  &
                     + gammax * (ey(ix+1, iy+1, iz-1) - ey(ix  , iy+1, iz-1)   &
                               + ey(ix+1, iy-1, iz-1) - ey(ix  , iy-1, iz-1)   &
                               + ey(ix+1, iy+1, iz+1) - ey(ix  , iy+1, iz+1)   &
                               + ey(ix+1, iy-1, iz+1) - ey(ix  , iy-1, iz+1))  &
                     + deltax * (ey(ix+2, iy  , iz  ) - ey(ix-1, iy  , iz  ))) &
                  + hdty * ( &
                       alphay * (ex(ix  , iy+1, iz  ) - ex(ix  , iy  , iz  ))  &
                     + betayx * (ex(ix+1, iy+1, iz  ) - ex(ix+1, iy  , iz  )   &
                               + ex(ix-1, iy+1, iz  ) - ex(ix-1, iy  , iz  ))  &
                     + betayz * (ex(ix  , iy+1, iz+1) - ex(ix  , iy  , iz+1)   &
                               + ex(ix  , iy+1, iz-1) - ex(ix  , iy  , iz-1))  &
                     + gammay * (ex(ix+1, iy+1, iz-1) - ex(ix+1, iy  , iz-1)   &
                               + ex(ix-1, iy+1, iz-1) - ex(ix-1, iy  , iz-1)   &
                               + ex(ix+1, iy+1, iz+1) - ex(ix+1, iy  , iz+1)   &
                               + ex(ix-1, iy+1, iz+1) - ex(ix-1, iy  , iz+1))  &
                     + deltay * (ex(ix  , iy+2, iz  ) - ex(ix  , iy-1, iz  )))
              ENDDO
            ENDDO
          ENDDO
        ENDIF
      ELSE IF (field_order == 4) THEN
        c1 = 9.0_num / 8.0_num
        c2 = -1.0_num / 24.0_num

        DO iz = 1, nz
          cz1 = c1 * hdtz
          cz2 = c2 * hdtz
          DO iy = 1, ny
            cy1 = c1 * hdty
            cy2 = c2 * hdty
            DO ix = 1, nx
              cx1 = c1 * hdtx
              cx2 = c2 * hdtx

              bx(ix, iy, iz) = bx(ix, iy, iz) &
                  - cy1 * (ez(ix  , iy+1, iz  ) - ez(ix  , iy  , iz  )) &
                  - cy2 * (ez(ix  , iy+2, iz  ) - ez(ix  , iy-1, iz  )) &
                  + cz1 * (ey(ix  , iy  , iz+1) - ey(ix  , iy  , iz  )) &
                  + cz2 * (ey(ix  , iy  , iz+2) - ey(ix  , iy  , iz-1))

              by(ix, iy, iz) = by(ix, iy, iz) &
                  - cz1 * (ex(ix  , iy  , iz+1) - ex(ix  , iy  , iz  )) &
                  - cz2 * (ex(ix  , iy  , iz+2) - ex(ix  , iy  , iz-1)) &
                  + cx1 * (ez(ix+1, iy  , iz  ) - ez(ix  , iy  , iz  )) &
                  + cx2 * (ez(ix+2, iy  , iz  ) - ez(ix-1, iy  , iz  ))

              bz(ix, iy, iz) = bz(ix, iy, iz) &
                  - cx1 * (ey(ix+1, iy  , iz  ) - ey(ix  , iy  , iz  )) &
                  - cx2 * (ey(ix+2, iy  , iz  ) - ey(ix-1, iy  , iz  )) &
                  + cy1 * (ex(ix  , iy+1, iz  ) - ex(ix  , iy  , iz  )) &
                  + cy2 * (ex(ix  , iy+2, iz  ) - ex(ix  , iy-1, iz  ))
            ENDDO
          ENDDO
        ENDDO
      ELSE
        c1 = 75.0_num / 64.0_num
        c2 = -25.0_num / 384.0_num
        c3 = 3.0_num / 640.0_num

        DO iz = 1, nz
          cz1 = c1 * hdtz
          cz2 = c2 * hdtz
          cz3 = c3 * hdtz
          DO iy = 1, ny
            cy1 = c1 * hdty
            cy2 = c2 * hdty
            cy3 = c3 * hdty
            DO ix = 1, nx
              cx1 = c1 * hdtx
              cx2 = c2 * hdtx
              cx3 = c3 * hdtx

              bx(ix, iy, iz) = bx(ix, iy, iz) &
                  - cy1 * (ez(ix  , iy+1, iz  ) - ez(ix  , iy  , iz  )) &
                  - cy2 * (ez(ix  , iy+2, iz  ) - ez(ix  , iy-1, iz  )) &
                  - cy3 * (ez(ix  , iy+3, iz  ) - ez(ix  , iy-2, iz  )) &
                  + cz1 * (ey(ix  , iy  , iz+1) - ey(ix  , iy  , iz  )) &
                  + cz2 * (ey(ix  , iy  , iz+2) - ey(ix  , iy  , iz-1)) &
                  + cz3 * (ey(ix  , iy  , iz+3) - ey(ix  , iy  , iz-2))

              by(ix, iy, iz) = by(ix, iy, iz) &
                  - cz1 * (ex(ix  , iy  , iz+1) - ex(ix  , iy  , iz  )) &
                  - cz2 * (ex(ix  , iy  , iz+2) - ex(ix  , iy  , iz-1)) &
                  - cz3 * (ex(ix  , iy  , iz+3) - ex(ix  , iy  , iz-2)) &
                  + cx1 * (ez(ix+1, iy  , iz  ) - ez(ix  , iy  , iz  )) &
                  + cx2 * (ez(ix+2, iy  , iz  ) - ez(ix-1, iy  , iz  )) &
                  + cx3 * (ez(ix+3, iy  , iz  ) - ez(ix-2, iy  , iz  ))

              bz(ix, iy, iz) = bz(ix, iy, iz) &
                  - cx1 * (ey(ix+1, iy  , iz  ) - ey(ix  , iy  , iz  )) &
                  - cx2 * (ey(ix+2, iy  , iz  ) - ey(ix-1, iy  , iz  )) &
                  - cx3 * (ey(ix+3, iy  , iz  ) - ey(ix-2, iy  , iz  )) &
                  + cy1 * (ex(ix  , iy+1, iz  ) - ex(ix  , iy  , iz  )) &
                  + cy2 * (ex(ix  , iy+2, iz  ) - ex(ix  , iy-1, iz  )) &
                  + cy3 * (ex(ix  , iy+3, iz  ) - ex(ix  , iy-2, iz  ))
            ENDDO
          ENDDO
        ENDDO
      ENDIF
    ENDIF

  END SUBROUTINE update_b_field



  SUBROUTINE update_eb_fields_half

    hdt  = 0.5_num * dt
    hdtx = hdt / dx
    hdty = hdt / dy
    hdtz = hdt / dz

    cnx = hdtx * c**2
    cny = hdty * c**2
    cnz = hdtz * c**2

    fac = hdt / epsilon0

    ! Update E field to t+dt/2
    CALL update_e_field

    ! Now have E(t+dt/2), do boundary conditions on E
    CALL efield_bcs

    ! Update B field to t+dt/2 using E(t+dt/2)
    CALL update_b_field

    ! Now have B field at t+dt/2. Do boundary conditions on B
    CALL bfield_bcs(.TRUE.)

    ! Now have E&B fields at t = t+dt/2
    ! Move to particle pusher

  END SUBROUTINE update_eb_fields_half



  SUBROUTINE update_eb_fields_final

    hdt  = 0.5_num * dt
    hdtx = hdt / dx
    hdty = hdt / dy
    hdtz = hdt / dz

    cnx = hdtx * c**2
    cny = hdty * c**2
    cnz = hdtz * c**2

    fac = hdt / epsilon0

    CALL update_b_field

    CALL bfield_final_bcs

    CALL update_e_field

    CALL efield_bcs

  END SUBROUTINE update_eb_fields_final

END MODULE fields

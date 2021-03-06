include	<mach.h>
include	<pkg/gtools.h>


# ING_NEAREST -- Find the nearest point to the cursor and return the index.
# The cursor is moved to the nearest point selected.

int procedure ing_nearestr (in, gp, gt, nl, x, y, npts, nvars, wx, wy)

pointer	in				# INLFIT pointer
pointer	gp				# GIO pointer
pointer	gt				# GTOOLS pointer
pointer	nl				# NLFIT pointer
real	x[ARB]				# Independent variables (npts * nvars)
real	y[npts]				# Dependent variables
int	npts				# Number of points
int	nvars				# Number of variables
real	wx, wy				# Cursor position

int	pt
pointer	sp, xout, yout

int	ing_nr(), gt_geti()

begin
	# Allocate memory for axes data
	call smark (sp)
	call salloc (xout, npts, TY_REAL)
	call salloc (yout, npts, TY_REAL)

	# Set axes data
	call ing_axesr (in, gt, nl, 1, x, y, Memr[xout], npts, nvars)
	call ing_axesr (in, gt, nl, 2, x, y, Memr[yout], npts, nvars)

	# Check for transposed axes
	if (gt_geti (gt, GTTRANSPOSE) == NO)
	    pt = ing_nr (gp, Memr[xout], Memr[yout], npts, wx, wy)
	else
	    pt = ing_nr (gp, Memr[yout], Memr[xout], npts, wy, wx)
	call sfree (sp)
	
	# Return index
	return (pt)
end


# ING_N -- Find position and move the cursor.

int procedure ing_nr (gp, x, y, npts, wx, wy)

pointer	gp					# GIO pointer
real	x[npts], y[npts]			# Data points
int	npts					# Number of points
real	wx, wy					# Cursor position

int	i, j
real	xc, yc, x0, y0, r2, r2min

begin
	# Transform world cursor coordinates to NDC.
	call gctran (gp, wx, wy, xc, yc, 1, 0)

	# Search for nearest point.
	r2min = MAX_REAL
	do i = 1, npts {
	    call gctran (gp, real (x[i]), real (y[i]), x0, y0, 1, 0)
	    r2 = (x0 - xc) ** 2 + (y0 - yc) ** 2
	    if (r2 < r2min) {
		r2min = r2
		j = i
	    }
	}

	# Move the cursor to the selected point and return the index.
	if (j != 0) {
	    call gscur (gp, real (x[j]), real (y[j]))
	    wx = x[j]
	    wy = y[j]
	}
	return (j)
end

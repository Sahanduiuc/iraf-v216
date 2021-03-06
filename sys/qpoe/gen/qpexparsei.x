# Copyright(c) 1986 Association of Universities for Research in Astronomy Inc.

include <syserr.h>
include <ctype.h>
include <mach.h>
include "../qpex.h"

.help qpexparse
.nf --------------------------------------------------------------------------
QPEXPARSE -- Code to parse an event attribute expression, producing a binary
range list as output.

	nranges = qpex_parse[ird] (expr, xs, xe, xlen)

The calling sequence for the parse routine is shown above.  The arguments XS
and XE are pointers to dynamically allocated arrays of length XLEN and type
[IRD].	These arrays should be allocated in the calling program before calling
the parser, and deallocated when no longer needed.  Reallocation to increase
the array length is automatic if the arrays fill during parsing.  DTYPE should
be the same datatype as the attribute with which the list is associated.

The form of an event attribute expression may be a list of values,

	attribute = n
or
	attribute = m, n, ...

a list of inclusive or exclusive ranges,

	attribute = m:n, !p:q

including open ranges,

	attribute = :n, p:q

or any combination of the above (excluding combinations of bitmasks and values
or ranges, which are mutually exclusive):

	attribute = :n, a, b, p:q, !(m, e:f)

Parenthesis may be used for grouping where desired, e.g.,

	attribute = (:n, a, b, p:q, !(m, e:f))

An additional form of the event attribute expression allows use of a bitmask
to specify the acceptable values, e.g.,

	attribute = %17B
or
	attribute = !%17B

however, bitmasks are incompatible with range lists, and should be recognized
and dealt with elsewhere (bitmasks may not be combined with range lists in
the same expression term).

We are concerned here only with the attribute value list itself, i.e.,
everything to the right of the equals sign in the examples above.  This list
should be extracted and placed into a string containing a single line of
text before we are called.  Attribute value lists may be any length, but
backslash continuation, file inclusion (or whatever means is used to form
the attribute value list) is assumed to be handled at a higher level.

The output of this package is an ordered boolean valued binary range list
with type integer, real, or double breakpoints (i.e., the breakpoints are the
same datatype as the attribute itself, but the range values are zero or one).
The range list defines the initial value, final value, and any interior
breakpoints where the attribute value changes state.  Expression optimization
is used to minimize the number of breakpoints (i.e., eliminate redundant
breakpoints, such as a range within a range).

Output range list format:

	xs[1] xe[1]
	xs[2] xe[2]
	    ...
	xs[N] xe[N]

Where each range is inclusive and only "true" ranges are shown.  If XS[1] is
LEFT a open-left range (:n) is indicated; if XE[N] is RIGHT an open-right
range (n:) is indicated.  In an integer range list, isolated points appear
as a single range with (xe[i]=xs[i]).  In a real or double range list,
isolated points are represented as finite ranges with a width on the order of
the machine epsilon.
.endhelp ---------------------------------------------------------------------

define	DEF_XLEN	256		# default output range list length
define	INC_XLEN	256		# increment to above
define	DEF_VLEN	512		# default breakpoint list length
define	INC_VLEN	512		# increment to above
define	MAX_NEST	20		# parser stack depth

define	STEP		1		# step at boundary of closed range
define	ZERO		1000		# step at boundary of open range

define	XV	Memi[xv+($1)-1]	# reference x position values
define	UV	Memi[uv+($1)-1]		# unique flags for x value pairs
define	SV	Memi[sv+($1)-1] 	# reference breakpoint step values


# QPEX_PARSE -- Convert the given attribute value list into a binary
# range list, returning the number of ranges as the function value.

int procedure qpex_parsei (expr, xs, xe, xlen)

char	expr[ARB]		#I attribute value list to be parsed
pointer xs			#U pointer to array of start-range values
pointer xe			#U pointer to array of	 end-range values
int	xlen			#U allocated length of XS, XE arrays

bool	range
pointer xv, uv, sv
int	xstart, xend, xmin, temp, x, n_xs, n_xe
int	vlen, nrg, ip, op, ch, ip_start, i, j, jval, r1, r2, y, v, ov, dy
int	token[MAX_NEST], tokval[MAX_NEST], lev, itemp, umin
errchk	syserr, malloc, realloc
define	pop_ 91

int	qp_ctoi()
define	fp_equali($1==$2)

begin
	vlen = DEF_VLEN
	call malloc (xv, vlen, TY_INT)
	call malloc (uv, vlen, TY_INT)
	call malloc (sv, vlen, TY_INT)

	lev = 0
	nrg = 0

	# Parse the expression string and compile the raw, unoptimized
	# breakpoint list in the order in which the breakpoints occur in
	# the string.

	for (ip=1;  expr[ip] != EOS;  ) {
	    # Skip whitespace.
	    for (ch=expr[ip];  IS_WHITE(ch) || ch == '\n';  ch=expr[ip])
		ip = ip + 1

	    # Extract and process token.
	    switch (ch) {
	    case EOS:
		# At end of string.
		if (lev > 0)
		    goto pop_
		else
		    break

	    case ',':
		# Comma list token delmiter.
		ip = ip + 1
		goto pop_

	    case '!', '(':
		# Syntactical element - push on stack.
		ip = ip + 1
		lev = lev + 1
		if (lev > MAX_NEST)
		    call syserr (SYS_QPEXLEVEL)
		token[lev] = ch
		tokval[lev] = nrg + 1

	    case ')':
		# Close parenthesized group and pop parser stack.
		ip = ip + 1
		if (lev < 1)
		    call syserr (SYS_QPEXMLP)
		else if (token[lev] != '(')
		    call syserr (SYS_QPEXRPAREN)
		lev = lev - 1
		goto pop_

	    default:
		# Process a range term.
		ip_start = ip

		# Scan the M in M:N.
		    if (qp_ctoi (expr, ip, xstart) <= 0)
			xstart = LEFTI

		# Scan the : in M:N.  The notation M-N is also accepted,
		# provided the token - immediately follows the token M.

		while (IS_WHITE(expr[ip]))
		    ip = ip + 1
		range = (expr[ip] == ':')
		if (range)
		    ip = ip + 1
		else if (!IS_LEFTI (xstart)) {
		    range = (expr[ip] == '-')
		    if (range)
			ip = ip + 1
		}

		# Scan the N in M:N.
		if (range) {
			if (qp_ctoi (expr, ip, xend) <= 0)
			    xend = RIGHTI
		} else
		    xend = xstart

		# Fix things if the user entered M:M explicitly.
		if (range)
		    if (fp_equali (xstart, xend))
			range = false

		# Expand a single point into a range.  For an integer list
		# this produces M:M+1; for a floating list M-eps:M+eps.
		# Verify ordering and that something recognizable was scanned.

		if (!range) {
		    if (IS_LEFTI(xstart))
			call syserr (SYS_QPEXBADRNG)
			xend   = xstart + 1
		} else {
		    if (xstart > xend) {
			temp = xstart;  xstart = xend;  xend = temp
		    }
			if (!IS_RIGHTI(xend))
			    xend = xend + 1
		}

		# Make more space if vectors fill up.
		if (nrg+4 > vlen) {
		    vlen = vlen + INC_VLEN
		    call realloc (xv, vlen, TY_INT)
		    call realloc (uv, vlen, TY_INT)
		    call realloc (sv, vlen, TY_INT)
		}

		# Save range on intermediate breakpoint list.
		nrg = nrg + 1
		XV(nrg) = xstart
		UV(nrg) = 0
		SV(nrg) = STEP

		nrg = nrg + 1
		XV(nrg) = xend
		UV(nrg) = 1
		SV(nrg) = -STEP
pop_
		# Pop parser stack.
		if (lev > 0)
		    if (token[lev] == '!') {
			# Invert a series of breakpoints.
			do i = tokval[lev], nrg {
			    if (SV(i) == STEP)		# invert
				SV(i) = -ZERO
			    else if (SV(i) == -STEP)
				SV(i) = ZERO
			    else if (SV(i) == ZERO)	# undo
				SV(i) = -STEP
			    else if (SV(i) == -ZERO)
				SV(i) = STEP
			}
			lev = lev - 1
		    }
	    }
	}

	# If the first range entered by the user is an exclude range,
	# e.g., "(!N)" or "(!(expr))" this implies that all other values
	# are acceptable.  Add the open range ":" to the end of the range
	# list to indicate this, i.e., convert "!N" to ":,!N".

	if (SV(1) == -ZERO) {
	    nrg = nrg + 1
	    XV(nrg) = LEFTI
	    UV(nrg) = 0
	    SV(nrg) = STEP

	    nrg = nrg + 1
	    XV(nrg) = RIGHTI
	    UV(nrg) = 1
	    SV(nrg) = -STEP
	}

	# Sort the breakpoint list.
	do j = 1, nrg {
	    xmin = XV(j);  umin = UV(j)
	    jval = j
	    do i = j+1, nrg {
		if (XV(i) < xmin || (XV(i) == xmin && UV(i) < umin)) {
		    xmin = XV(i);  umin = UV(i)
		    jval = i
		}
	    }
	    if (jval != j) {
		temp  = XV(j);  XV(j) = XV(jval);  XV(jval) = temp
		itemp = UV(j);  UV(j) = UV(jval);  UV(jval) = itemp
		itemp = SV(j);  SV(j) = SV(jval);  SV(jval) = itemp
	    }
	}

	# Initialize the output arrays if they were passed in as null.
	if (xlen <= 0) {
	    xlen = DEF_XLEN
	    call malloc (xs, xlen, TY_INT)
	    call malloc (xe, xlen, TY_INT)
	}

	# Collapse sequences of redundant breakpoints into a single
	# breakpoint, clipping the running sum value to the range 0-1.	
	# Accumulate and output successive nonzero ranges.

	op = 1
	ov = 0
	y  = 0

	for (r1=1;  r1 <= nrg;	r1=r2+1) {
	    # Get a range of breakpoint entries for a single XV position.
	    for (r2=r1;  r2 <= nrg;  r2=r2+1) {
		    if (XV(r2) != XV(r1))
			break
	    }
	    r2 = r2 - 1

	    # Collapse into a single breakpoint.
	    x  = XV(r1)
	    dy = SV(r1)
	    do i = r1 + 1, r2
		dy = dy + SV(i)
	    y = y + dy

	    # Clip value to the range 0-1.
	    v = max(0, min(1, y))

	    # Accumulate a range of nonzero value.  This eliminates redundant
	    # points lying within a range which is already set high.

	    if (v == 1 && ov == 0) {
		n_xs = x
		ov = 1
	    } else if (v == 0 && ov == 1) {
		    if (IS_RIGHTI(x))
			n_xe = x
		    else
			n_xe = x - 1
		ov = 2
	    }

	    # Output a range.
	    if (ov == 2) {
		if (op > xlen) {
		    xlen = xlen + INC_XLEN
		    call realloc (xs, xlen, TY_INT)
		    call realloc (xe, xlen, TY_INT)
		}

		Memi[xs+op-1] = n_xs
		Memi[xe+op-1] = n_xe
		op = op + 1

		ov = 0
	    }
	}

	# All done; discard breakpoint buffers.
	call mfree (xv, TY_INT)
	call mfree (uv, TY_INT)
	call mfree (sv, TY_INT)

	return (op - 1)
end

# Guix --- Nix package management from Guile.         -*- coding: utf-8 -*-
# Copyright (C) 2012 Ludovic Courtès <ludo@gnu.org>
#
# This file is part of Guix.
#
# Guix is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or (at
# your option) any later version.
#
# Guix is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Guix.  If not, see <http://www.gnu.org/licenses/>.

#
# Test the `guix-build' command-line utility.
#

guix-build --version

# Should fail.
guix-build -e + || true

# Should pass.
guix-build -e '(@@ (distro packages base) %bootstrap-guile)' |	\
    grep -e '-guile-'
guix-build hello -d |				\
    grep -e '-hello-[0-9\.]\+\.drv$'

# Should fail because the name/version combination could not be found.
if guix-build hello-0.0.1 -n; then false; else true; fi

# Keep a symlink to the result, registered as a root.
result="t-result-$$"
guix-build -r "$result"					\
    -e '(@@ (distro packages base) %bootstrap-guile)'
test -x "$result/bin/guile"

# Should fail, because $result already exists.
if guix-build -r "$result" -e '(@@ (distro packages base) %bootstrap-guile)'
then false; else true; fi

rm -f "$result"
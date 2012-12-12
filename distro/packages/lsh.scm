;;; Guix --- Nix package management from Guile.         -*- coding: utf-8 -*-
;;; Copyright (C) 2012 Ludovic Courtès <ludo@gnu.org>
;;;
;;; This file is part of Guix.
;;;
;;; Guix is free software; you can redistribute it and/or modify it
;;; under the terms of the GNU General Public License as published by
;;; the Free Software Foundation; either version 3 of the License, or (at
;;; your option) any later version.
;;;
;;; Guix is distributed in the hope that it will be useful, but
;;; WITHOUT ANY WARRANTY; without even the implied warranty of
;;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;; GNU General Public License for more details.
;;;
;;; You should have received a copy of the GNU General Public License
;;; along with Guix.  If not, see <http://www.gnu.org/licenses/>.

(define-module (distro packages lsh)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix build-system gnu)
  #:use-module (distro)
  #:use-module (distro packages m4)
  #:use-module (distro packages linux)
  #:use-module (distro packages compression)
  #:use-module (distro packages multiprecision)
  #:use-module (distro packages readline)
  #:use-module (distro packages gperf)
  #:use-module (distro packages base))

(define-public liboop
  (package
    (name "liboop")
    (version "1.0")
    (source
     (origin
      (method url-fetch)
      (uri (string-append "http://download.ofb.net/liboop/liboop-"
                          version ".tar.gz"))
      (sha256
       (base32
        "0z6rlalhvfca64jpvksppc9bdhs7jwhiw4y35g5ibvh91xp3rn1l"))))
    (build-system gnu-build-system)
    (home-page "http://liboop.ofb.net/")
    (synopsis "`liboop', an event loop library")
    (description "liboop is an event loop library.")
    (license "LGPLv2.1+")))

(define-public lsh
  (package
    (name "lsh")
    (version "2.0.4")
    (source
     (origin
      (method url-fetch)
      (uri (string-append "mirror://gnu/lsh/lsh-"
                          version ".tar.gz"))
      (sha256
       (base32
        "149hf49xcj99wwvi7hcb59igq4vpyv8har1br1if3lrsw5irsjv1"))))
    (build-system gnu-build-system)
    (inputs
     `(("linux-pam" ,linux-pam)
       ("m4" ,m4)
       ("readline" ,readline)
       ("liboop" ,liboop)
       ("zlib" ,zlib)
       ("gmp" ,gmp)
       ("guile" ,guile-final)
       ("gperf" ,gperf)
       ("psmisc" ,psmisc)                         ; for `killall'

       ("patch/no-root-login" ,(search-patch "lsh-no-root-login.patch"))
       ("patch/guile-compat" ,(search-patch "lsh-guile-compat.patch"))
       ("patch/pam-service-name"
        ,(search-patch "lsh-pam-service-name.patch"))))
    (arguments
     '(#:patches (list (assoc-ref %build-inputs "patch/no-root-login")
                       (assoc-ref %build-inputs "patch/pam-service-name")
                       (assoc-ref %build-inputs "patch/guile-compat"))

       ;; Skip the `configure' test that checks whether /dev/ptmx &
       ;; co. work as expected, because it relies on impurities (for
       ;; instance, /dev/pts may be unavailable in chroots.)
       #:configure-flags '("lsh_cv_sys_unix98_ptys=yes")

       ;; FIXME: Tests won't run in a chroot, presumably because
       ;; /etc/profile is missing, and thus clients get an empty $PATH
       ;; and nothing works.
       #:tests? #f

       #:phases
       (alist-cons-before
        'configure 'fix-test-suite
        (lambda _
          ;; Tests rely on $USER being set.
          (setenv "USER" "guix")

          (substitute* "src/testsuite/functions.sh"
            (("localhost")
             ;; Avoid host name lookups since they don't work in chroot
             ;; builds.
             "127.0.0.1")
            (("set -e")
             ;; Make tests more verbose.
             "set -e\nset -x"))

          (substitute* (find-files "src/testsuite" "-test$")
            (("localhost") "127.0.0.1"))

          (substitute* "src/testsuite/login-auth-test"
            (("/bin/cat")
             ;; Use the right path to `cat'.
             (search-path (search-path-as-string->list (getenv "PATH"))
                          "cat"))))
        %standard-phases)))
    (home-page "http://www.lysator.liu.se/~nisse/lsh/")
    (synopsis
     "GNU lsh, a GPL'd implementation of the SSH protocol")
    (description
     "lsh is a free implementation (in the GNU sense) of the ssh
version 2 protocol, currently being standardised by the IETF
SECSH working group.")
    (license "GPLv2+")))
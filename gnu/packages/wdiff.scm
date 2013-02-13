;;; GNU Guix --- Functional package management for GNU
;;; Copyright © 2013 Nikita Karetnikov <nikita@karetnikov.org>
;;;
;;; This file is part of GNU Guix.
;;;
;;; GNU Guix is free software; you can redistribute it and/or modify it
;;; under the terms of the GNU General Public License as published by
;;; the Free Software Foundation; either version 3 of the License, or (at
;;; your option) any later version.
;;;
;;; GNU Guix is distributed in the hope that it will be useful, but
;;; WITHOUT ANY WARRANTY; without even the implied warranty of
;;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;; GNU General Public License for more details.
;;;
;;; You should have received a copy of the GNU General Public License
;;; along with GNU Guix.  If not, see <http://www.gnu.org/licenses/>.

(define-module (gnu packages wdiff)
  #:use-module (guix licenses)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix build-system gnu)
  #:use-module (gnu packages screen)
  #:use-module (gnu packages which))

(define-public wdiff
  (package
    (name "wdiff")
    (version "1.1.2")
    (source
     (origin
      (method url-fetch)
      (uri (string-append "mirror://gnu/wdiff/wdiff-"
                          version ".tar.gz"))
      (sha256
       (base32
        "0q78y5awvjjmsvizqilbpwany62shlmlq2ayxkjbygmdafpk1k8j"))))
    (build-system gnu-build-system)
    (arguments
     `(#:phases (alist-cons-before
                 'check 'fix-sh
                 (lambda _
                   (substitute* "tests/testsuite"
                     (("#! /bin/sh")
                      (string-append "#!" (which "sh")))))
                 %standard-phases)))
    (inputs `(("screen" ,screen)
              ("which" ,which)))
    (home-page "https://www.gnu.org/software/wdiff/")
    (synopsis
     "GNU Wdiff, a tool for comparing files on a word by word basis")
    (description
     "GNU Wdiff is a front end to 'diff' for comparing files on a word per
word basis.  A word is anything between whitespace.  This is useful for
comparing two texts in which a few words have been changed and for which
paragraphs have been refilled.  It works by creating two temporary files, one
word per line, and then executes 'diff' on these files.  It collects the
'diff' output and uses it to produce a nicer display of word differences
between the original files.")
    (license gpl3+)))
;;; GNU Guix --- Functional package management for GNU
;;; Copyright © 2012, 2013 Ludovic Courtès <ludo@gnu.org>
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


(define-module (test-packages)
  #:use-module (guix store)
  #:use-module (guix utils)
  #:use-module (guix derivations)
  #:use-module (guix packages)
  #:use-module (guix build-system)
  #:use-module (guix build-system trivial)
  #:use-module (guix build-system gnu)
  #:use-module (gnu packages)
  #:use-module (gnu packages base)
  #:use-module (gnu packages bootstrap)
  #:use-module (srfi srfi-11)
  #:use-module (srfi srfi-26)
  #:use-module (srfi srfi-34)
  #:use-module (srfi srfi-64)
  #:use-module (rnrs io ports)
  #:use-module (ice-9 match))

;; Test the high-level packaging layer.

(define %store
  (false-if-exception (open-connection)))

(when %store
  ;; Make sure we build everything by ourselves.
  (set-build-options %store #:use-substitutes? #f))


(test-begin "packages")

(define-syntax-rule (dummy-package name* extra-fields ...)
  (package (name name*) (version "0") (source #f)
           (build-system gnu-build-system)
           (synopsis #f) (description #f)
           (home-page #f) (license #f)
           extra-fields ...))

(test-assert "package-field-location"
  (let ()
    (define (goto port line column)
      (unless (and (= (port-column port) (- column 1))
                   (= (port-line port) (- line 1)))
        (unless (eof-object? (get-char port))
          (goto port line column))))

    (define read-at
      (match-lambda
       (($ <location> file line column)
        (call-with-input-file (search-path %load-path file)
          (lambda (port)
            (goto port line column)
            (read port))))))

    ;; Until Guile 2.0.6 included, source properties were added only to pairs.
    ;; Thus, check against both VALUE and (FIELD VALUE).
    (and (member (read-at (package-field-location %bootstrap-guile 'name))
                 (let ((name (package-name %bootstrap-guile)))
                   (list name `(name ,name))))
         (member (read-at (package-field-location %bootstrap-guile 'version))
                 (let ((version (package-version %bootstrap-guile)))
                   (list version `(version ,version))))
         (not (package-field-location %bootstrap-guile 'does-not-exist)))))

(test-assert "package-transitive-inputs"
  (let* ((a (dummy-package "a"))
         (b (dummy-package "b"
              (propagated-inputs `(("a" ,a)))))
         (c (dummy-package "c"
              (inputs `(("a" ,a)))))
         (d (dummy-package "d"
              (propagated-inputs `(("x" "something.drv")))))
         (e (dummy-package "e"
              (inputs `(("b" ,b) ("c" ,c) ("d" ,d))))))
    (and (null? (package-transitive-inputs a))
         (equal? `(("a" ,a)) (package-transitive-inputs b))
         (equal? `(("a" ,a)) (package-transitive-inputs c))
         (equal? (package-propagated-inputs d)
                 (package-transitive-inputs d))
         (equal? `(("b" ,b) ("b/a" ,a) ("c" ,c)
                   ("d" ,d) ("d/x" "something.drv"))
                 (pk 'x (package-transitive-inputs e))))))

(test-skip (if (not %store) 8 0))

(test-assert "package-source-derivation, file"
  (let* ((file    (search-path %load-path "guix.scm"))
         (package (package (inherit (dummy-package "p"))
                    (source file)))
         (source  (package-source-derivation %store
                                             (package-source package))))
    (and (store-path? source)
         (valid-path? %store source)
         (equal? (call-with-input-file source get-bytevector-all)
                 (call-with-input-file file get-bytevector-all)))))

(test-assert "package-source-derivation, store path"
  (let* ((file    (add-to-store %store "guix.scm" #t "sha256"
                                (search-path %load-path "guix.scm")))
         (package (package (inherit (dummy-package "p"))
                    (source file)))
         (source  (package-source-derivation %store
                                             (package-source package))))
    (string=? file source)))

(test-assert "return values"
  (let-values (((drv-path drv)
                (package-derivation %store (dummy-package "p"))))
    (and (derivation-path? drv-path)
         (derivation? drv))))

(test-assert "package-output"
  (let* ((package  (dummy-package "p"))
         (drv-path (package-derivation %store package)))
    (and (derivation-path? drv-path)
         (string=? (derivation-path->output-path drv-path)
                   (package-output %store package "out")))))

(test-assert "trivial"
  (let* ((p (package (inherit (dummy-package "trivial"))
              (build-system trivial-build-system)
              (source #f)
              (arguments
               `(#:guile ,%bootstrap-guile
                 #:builder
                 (begin
                   (mkdir %output)
                   (call-with-output-file (string-append %output "/test")
                     (lambda (p)
                       (display '(hello guix) p))))))))
         (d (package-derivation %store p)))
    (and (build-derivations %store (list d))
         (let ((p (pk 'drv d (derivation-path->output-path d))))
           (equal? '(hello guix)
                   (call-with-input-file (string-append p "/test") read))))))

(test-assert "trivial with local file as input"
  (let* ((i (search-path %load-path "ice-9/boot-9.scm"))
         (p (package (inherit (dummy-package "trivial-with-input-file"))
              (build-system trivial-build-system)
              (source #f)
              (arguments
               `(#:guile ,%bootstrap-guile
                 #:builder (copy-file (assoc-ref %build-inputs "input")
                                      %output)))
              (inputs `(("input" ,i)))))
         (d (package-derivation %store p)))
    (and (build-derivations %store (list d))
         (let ((p (pk 'drv d (derivation-path->output-path d))))
           (equal? (call-with-input-file p get-bytevector-all)
                   (call-with-input-file i get-bytevector-all))))))

(test-assert "trivial with system-dependent input"
  (let* ((p (package (inherit (dummy-package "trivial-system-dependent-input"))
              (build-system trivial-build-system)
              (source #f)
              (arguments
               `(#:guile ,%bootstrap-guile
                 #:builder
                 (let ((out  (assoc-ref %outputs "out"))
                       (bash (assoc-ref %build-inputs "bash")))
                   (zero? (system* bash "-c"
                                   (format #f "echo hello > ~a" out))))))
              (inputs `(("bash" ,(search-bootstrap-binary "bash"
                                                          (%current-system)))))))
         (d (package-derivation %store p)))
    (and (build-derivations %store (list d))
         (let ((p (pk 'drv d (derivation-path->output-path d))))
           (eq? 'hello (call-with-input-file p read))))))

(test-assert "search paths"
  (let* ((p (make-prompt-tag "return-search-paths"))
         (s (build-system
             (name "raw")
             (description "Raw build system with direct store access")
             (build (lambda* (store name source inputs
                                    #:key outputs system search-paths)
                      search-paths))))
         (x (list (search-path-specification
                   (variable "GUILE_LOAD_PATH")
                   (directories '("share/guile/site/2.0")))
                  (search-path-specification
                   (variable "GUILE_LOAD_COMPILED_PATH")
                   (directories '("share/guile/site/2.0")))))
         (a (package (inherit (dummy-package "guile"))
              (build-system s)
              (native-search-paths x)))
         (b (package (inherit (dummy-package "guile-foo"))
              (build-system s)
              (inputs `(("guile" ,a)))))
         (c (package (inherit (dummy-package "guile-bar"))
              (build-system s)
              (inputs `(("guile" ,a)
                        ("guile-foo" ,b))))))
    (let-syntax ((collect (syntax-rules ()
                            ((_ body ...)
                             (call-with-prompt p
                               (lambda ()
                                 body ...)
                               (lambda (k search-paths)
                                 search-paths))))))
      (and (null? (collect (package-derivation %store a)))
           (equal? x (collect (package-derivation %store b)))
           (equal? x (collect (package-derivation %store c)))))))

(test-assert "package-cross-derivation"
  (let-values (((drv-path drv)
                (package-cross-derivation %store (dummy-package "p")
                                          "mips64el-linux-gnu")))
    (and (derivation-path? drv-path)
         (derivation? drv))))

(test-assert "package-cross-derivation, trivial-build-system"
  (let ((p (package (inherit (dummy-package "p"))
             (build-system trivial-build-system)
             (arguments '(#:builder (exit 1))))))
    (let-values (((drv-path drv)
                  (package-cross-derivation %store p "mips64el-linux-gnu")))
      (and (derivation-path? drv-path)
           (derivation? drv)))))

(test-assert "package-cross-derivation, no cross builder"
  (let* ((b (build-system (inherit trivial-build-system)
              (cross-build #f)))
         (p (package (inherit (dummy-package "p"))
              (build-system b))))
    (guard (c ((package-cross-build-system-error? c)
               (eq? (package-error-package c) p)))
      (package-cross-derivation %store p "mips64el-linux-gnu")
      #f)))

(unless (false-if-exception (getaddrinfo "www.gnu.org" "80" AI_NUMERICSERV))
  (test-skip 1))
(test-assert "GNU Make, bootstrap"
  ;; GNU Make is the first program built during bootstrap; we choose it
  ;; here so that the test doesn't last for too long.
  (let ((gnu-make (@@ (gnu packages base) gnu-make-boot0)))
    (and (package? gnu-make)
         (or (location? (package-location gnu-make))
             (not (package-location gnu-make)))
         (let* ((drv (package-derivation %store gnu-make))
                (out (derivation-path->output-path drv)))
           (and (build-derivations %store (list drv))
                (file-exists? (string-append out "/bin/make")))))))

(test-eq "fold-packages" hello
  (fold-packages (lambda (p r)
                   (if (string=? (package-name p) "hello")
                       p
                       r))
                 #f))

(test-assert "find-packages-by-name"
  (match (find-packages-by-name "hello")
    (((? (cut eq? hello <>))) #t)
    (wrong (pk 'find-packages-by-name wrong #f))))

(test-assert "find-packages-by-name with version"
  (match (find-packages-by-name "hello" (package-version hello))
    (((? (cut eq? hello <>))) #t)
    (wrong (pk 'find-packages-by-name wrong #f))))

(test-end "packages")


(exit (= (test-runner-fail-count (test-runner-current)) 0))

;;; Local Variables:
;;; eval: (put 'dummy-package 'scheme-indent-function 1)
;;; End:

;;; -*- Mode:Lisp; Syntax:ANSI-Common-Lisp; Coding:utf-8 -*-

(in-package cl-bayesian-tests)

(deftestsuite samplers-tests (cl-bayesian-tests)
  ())

(addtest (samplers-tests)
  lr-kv-dummy-2phase
  (let+ ((k 2)
         (n 10)
         ((&values y x) (cl-random-tests:random-y-x (* 2 n) k))
         (variance 7)
         ;; single step
         (p2 (lr-kv y x variance))
         ;; two steps, first half
         (h1 (si 0 n))
         (p1 (lr-kv (sub y h1) (sub x h1 t) variance))
         ;; second half, using first half as prior
         (h2 (si n 0))
         (p2-1 (lr-kv (sub y h2) (sub x h2 t) variance :prior p1)))
    (ensure-same (mean p2) (mean p2-1))
    (ensure-same (variance p2) (variance p2-1))))

(addtest (samplers-tests)
  lr-kv-small
  (let+ ((x (clo 1 1 :/
                 1 2
                 1 3
                 1 4
                 1 5
                 1 6
                 1 7))
         (y (clo 2 2 3 4 5 6 6))
         (sd 19d0)
         (lr (lr-kv y x (expt sd 2)))
         ((&accessors-r/o mean variance) lr)
         (x-t (e/ x sd))
         (y-t (e/ y sd)))
    (ensure-same mean (solve (mm t x-t) (mm (transpose x-t) y-t)))
    (ensure-same variance (invert (mm t x-t)))))

(addtest (samplers-tests)
  multivariate-normal-model
  (let+ ((*lift-equality-test* #'==)
         (k 2)
         (n 10)
         (y (filled-array (list (* 2 n) k) (curry #'random 10d0)
                          'double-float))
         ;; single step
         (p2 (multivariate-normal-model y))
         ;; two steps
         (p1 (multivariate-normal-model (sub y (si 0 n) t)))
         (p2-1 (multivariate-normal-model (sub y (si n 0) t)
                                          :prior p1)))
    (ensure-same (mean p2) (mean p2-1))
    (ensure-same (nu p2) (nu p2-1))
    (ensure-same (inverse-scale p2) (mean p2-1))
    (ensure-same (kappa p2) (nu p2-1))

    ))
  

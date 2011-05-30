(defpackage cl-bayesian (:nicknames mcmc)
  (:use common-lisp iterate bind let-plus anaphora cl-num-utils alexandria
        lla cl-random lla)
  (:shadowing-import-from cl-num-utils
                          mean variance xor) ; also in alexandria
  (:export
   
   ;; utilities - nothing is exported

   ;; layout

   extract layout-length parse-layout flatten-into named-layout
   scalar-layout 

   ;; mcmc

   initialize-chain parameters-layout scalar-parameters-layout model
   update-chain state sample-chain reset-chain parameters scalar-parameters 
   chain
   
   update parameters parameters-index reset run

   ;; slice-sample

   slice-sample-so

   ;; samplers
   
   variance-distribution lr-kv-dummies lr-kv multivariate-normal-model kappa
   inverse-scale
   
   ;; chains

   mcmc-chains mcmc-class initargs parameters-ix chains chain-results burn-in 
   pooled-parameters run-mcmc-chains psrf chains-psrf
   calculate-pooled-parameters

   ))

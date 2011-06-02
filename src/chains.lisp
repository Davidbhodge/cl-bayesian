;;; -*- Mode:Lisp; Syntax:ANSI-Common-Lisp; Coding:utf-8 -*-

(in-package #:cl-bayesian)

(defstruct psrf 
  "Potential scale reduction factor."
  r
  v
  w)

(defun psrf (accumulators &key (confidence 0.975d0))
  "Estimate the potential scale reduction factor.  Algorithm is from Gelman and
Rubin (1992), but the degrees of freedom correction is according to Brooks and
Gelman (1998)."
  ;; !!! should return the upper limit of the confidence interval as the
  ;; second value.  Since the F distribution is not implemented yet in
  ;; cl-random, this functionality is not available now.
  (declare (ignore confidence))
  (let+ (;; length and number of chains
         (m (length accumulators))
         (n (common accumulators :key #'tally))
         ;; means and variances for each
         (means (map 'vector #'mean accumulators))
         (variances (map 'vector #'variance accumulators))
         ;; calculate psrf
         ((&accessors (mu mean) (var-m variance)) (sweep 'sse means))
         (b (* n var-m))
         ((&accessors (w mean) (var-v variance)) (sweep 'sse variances))
         (var-b (/ (* 2 (expt b 2)) (1- m)))
         (var-w (/ var-v m))
         (1+1/m (1+ (/ m)))
         (n-1 (1- n))
         (V (/ (+ (* n-1 w) (* 1+1/m b)) n))
         (var-V (/ (+ (* (expt n-1 2) var-w)
                      (* (expt 1+1/m 2) var-b)
                      (* 2 1+1/m n-1 (/ n m)
                         (- (covariance-xy variances (eexpt means 2))
                            (* 2 mu (covariance-xy variances means)))))
                   (expt n 2)))
         (df (/ (* 2 (expt V 2)) var-V))
         (df-adj (/ (+ df 3) (1+ df)))
         ;; (b-df (1- m))
         ;; (w-df (/ (* 2 (expt w 2)) var-w))
         (R^2-fixed (/ n-1 n))
         (R^2-random (* (/ 1+1/m n) (/ b w))))
    (make-psrf :R (sqrt (* df-adj (+ R^2-fixed R^2-random)))
               :V V
               :W w)))

(defun psrf-ranges (n &key (divisions 20) (burn-in-fraction 0.5)
                           (minimum-length 100))
  "Calculate ranges for PSRF.  Return as a list of (start . end) values.
Ranges narrower than MINIMUM-LENGTH are discarded."
  (iter
    (for division from 1 to divisions) 
    (let* ((end (ceiling (* division n) divisions))
           (start (floor (* end burn-in-fraction))))
      (when (<= (+ start minimum-length) end)
        (collect (cons start end))))))

(defclass column-statistics ()
  ((autocovariance-accumulators :initarg :autocovariance-accumulators
                                :documentation "Vector of autocovariance
                                accumulators for each variable.")
   (partial-ranges :initarg :partial-ranges)
   (partial-accumulators :initarg :partial-accumulators
                         :documentation "Vector of partial mean-sse
                         accumulators for each variable.")))

(defun column-statistics (matrix partial-ranges &key (lags 10))
  "Helper function to calculate column statistics."
  (let+ (((nrow ncol) (array-dimensions matrix))
         (autocovariance-accumulators
          (filled-array ncol (curry #'autocovariance-accumulator lags)))
         ((&values subranges index-lists)
          (subranges partial-ranges :shadow-ranges (list (cons 0 nrow))))
         (accumulators
          (combine
           (map 'vector
                (lambda+ ((start . end))
                  (let ((accumulators (filled-array ncol
                                                    #'mean-sse-accumulator))
                        (row-major-index (array-row-major-index matrix
                                                                start 0)))
                    (loop repeat (max 0 (- end start)) do
                      (dotimes (column-index ncol)
                        (let ((value (row-major-aref matrix row-major-index)))
                          (add (aref accumulators column-index) value)
                          (add (aref autocovariance-accumulators column-index)
                               value))
                        (incf row-major-index)))
                    accumulators))
                subranges)))
         (partial-accumulators
          (map1 (lambda (accumulators)
                  (iter
                    (for index-list :in-vector index-lists)
                    (let ((accumulators (sub accumulators
                                             (coerce index-list 'vector))))
                      (collect (pool* accumulators) :result-type vector))))
                (subarrays (transpose accumulators) 1))))
    (d:v subranges)
    (make-instance 'column-statistics
                   :autocovariance-accumulators autocovariance-accumulators
                   :partial-ranges partial-ranges
                   :partial-accumulators partial-accumulators)))

;; (defclass mcmc-chains ()
;;   ((mcmc-class :accessor mcmc-class :initarg :mcmc-class :documentation
;;                "Class used for creating MCMC instances.")
;;    (initargs :accessor initargs :initarg :initargs :documentation
;;              "Initial arguments used for creating MCMC instances.")
;;    (parameters-ix :accessor parameters-ix :initarg :parameters-ix
;;                   :documentation "Index for the parameter vectors.")
;;    (chains :accessor chains :initarg :chains :documentation
;;            "Chains, always holding the current state.")
;;    (chain-results :accessor chain-results :initarg :chain-results
;;                   :type simple-vector
;;                   :documentation "Matrices holding the chain-results.")
;;    (burn-in :accessor burn-in :initarg :burn-in
;;             :documentation "Burn-in, used to discard start of the sequence
;;             before inference.")
;;    (pooled-parameters :accessor pooled-parameters :documentation
;;                       "Pooled parameters.")))

;; (defun run-mcmc-chains (m n mcmc-class initargs &key (burn-in (floor n 2))
;;                         (thin 1))
;;   "Run M MCMC chains, each of length N, with given class and initargs."
;;   (iter
;;     (with parameters-ix)
;;     (for chain-index :below m)
;;     (format t "Running chain ~A/~A~%" chain-index (1- m))
;;     (let ((mcmc (apply #'make-instance mcmc-class initargs)))
;;       (collecting (run-mcmc mcmc n :burn-in 0 :thin thin)
;;                   :result-type vector :into chain-results)
;;       (collecting mcmc :result-type vector :into chains)
;;       (when (first-iteration-p)
;;         (setf parameters-ix (parameters-ix mcmc)))
;;       (finally 
;;        (return
;;          (make-instance 'mcmc-chains
;;                         :chains chains
;;                         :chain-results chain-results
;;                         :initargs initargs
;;                         :parameters-ix parameters-ix
;;                         :mcmc-class mcmc-class
;;                         :burn-in burn-in))))))




;; (defun chains-psrf (mcmc-chains &key (divisions 20) (burn-in-fraction 2))
;;   "Calculate the potential scale reduction factor for "
;;   (let+ (((&slots-r/o chain-results) mcmc-chains)
;;          ((n k) (array-dimensions (aref chain-results 0)))
;;          (limits (iter
;;                    (for index :from 1 :to divisions)
;;                    (collecting (ceiling (* n index) divisions)
;;                                :result-type vector)))
;;          (psrf-matrix (make-array (list divisions k))))
;;     (dotimes (param-index k)
;;       (let ((sequences (map 'vector (lambda (chain) (sub chain t param-index))
;;                             chain-results)))
;;         (iter
;;           (for limit :in-vector limits :with-index limit-index)
;;           (let* ((start (floor limit burn-in-fraction))
;;                  (sequences (map 'vector (lambda (sequence)
;;                                            (subseq sequence start limit))
;;                                  sequences)))
;;             (setf (aref psrf-matrix limit-index param-index)
;;                   (psrf sequences))))))
;;     (values limits psrf-matrix)))

;; (defun calculate-pooled-parameters (mcmc-chains &key (start (burn-in mcmc-chains))
;;                                     (end (nrow (aref (chain-results mcmc-chains) 0))))
;;   "Combine MCMC chains into a single matrix, preserving column structure.
;; START and END mark the iterations used."
;;   (let+ ((chain-length (- end start))
;;          ((&slots-r/o chain-results) mcmc-chains)
;;          (m (length chain-results))
;;          (first-chain (aref chain-results 0))
;;          (pooled (make-array 
;;                         (list (* chain-length m) (ncol first-chain))
;;                         :element-type (array-element-type first-chain))))
;;     (iter
;;       (for chain :in-vector chain-results)
;;       (for end-row :from chain-length :by chain-length)
;;       (for start-row :previous end-row :initially 0)
;;       (setf (sub pooled (si start-row end-row) t)
;;             (sub chain (si start end) t)))
;;     pooled))

;; (defmethod slot-unbound (class (instance mcmc-chains)
;;                          (slot-name (eql 'pooled-parameters)))
;;   (setf (slot-value instance 'pooled-parameters)
;;         (calculate-pooled-parameters instance)))

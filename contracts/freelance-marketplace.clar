;; Freelance marketplace (STX escrow for jobs + milestones)
;; Simple demo / starter contract. Use & audit before production.

(define-constant err-unauthorized u100)
(define-constant err-job-not-found u101)
(define-constant err-insufficient-funds u102)
(define-constant err-not-client u103)
(define-constant err-not-worker u104)
(define-constant err-payment-failed u105)
(define-constant err-invalid u106)

;; Job struct stored in a map keyed by job-id (uint)
;; value stored as a tuple
(define-map jobs
  {job-id: uint}
  {
   client: principal,
   worker: principal,
   price: uint,
   funded: uint,
   status: (string-ascii 16)
  })

;; Each milestone stored in a map keyed by (job-id, milestone-id)
(define-map milestones
  {job-id: uint, mid: uint}
  {
   creator: principal,
   amount: uint,
   description: (string-ascii 256),
   approved: bool,
   paid: bool
  })

;; Simple reputation map tracked per principal
(define-map reputation
  {user: principal}
  {score: int})

;; Job counter
(define-data-var job-counter uint u0)

;; Milestone counters per job (map job-id -> current milestone count)
(define-map job-mid-counter {job-id: uint} {count: uint})

;; Utility: increment and return new job id
(define-private (next-job-id)
  (let ((id (var-get job-counter)))
    (begin
      (var-set job-counter (+ id u1))
      (ok id))))

;; Create a job: client sets worker and price
(define-public (create-job (worker principal) (price uint))
  (begin
    (asserts! (not (is-eq worker tx-sender)) (err err-invalid))
    (asserts! (> price u0) (err err-invalid))
    (let ((job-id (unwrap-panic (next-job-id))))
      (begin
        (map-set jobs
          { job-id: job-id }
          {
            client: tx-sender,
            worker: worker,
            price: price,
            funded: u0,
            status: "open"
          })
        ;; initialize milestone counter
        (map-set job-mid-counter { job-id: job-id } { count: u0 })
        (ok job-id)))))

;; Fund a job: transfer STX from caller into contract escrow and credit the job.funded
;; Caller must sign the transaction (tx-sender). This will transfer STX from tx-sender -> current-contract.
(define-public (fund-job (job-id uint) (amount uint))
  (begin
    (asserts! (> job-id u0) (err err-invalid))
    (asserts! (> amount u0) (err err-invalid))
    (let ((job (map-get? jobs { job-id: job-id })))
      (if (is-none job)
        (err err-job-not-found)
        (let ((job-tuple (unwrap-panic job)))
          (match (stx-transfer? amount tx-sender (as-contract tx-sender))
            transfer-ok
            (let ((new-funded (+ (get funded job-tuple) amount)))
              (begin
                (map-set jobs { job-id: job-id }
                  {
                    client: (get client job-tuple),
                    worker: (get worker job-tuple),
                    price: (get price job-tuple),
                    funded: new-funded,
                    status: (if (>= new-funded (get price job-tuple)) "funded" (get status job-tuple))
                  })
                (ok new-funded)))
            transfer-err (err err-payment-failed)))
        ))))

;; Worker submits a milestone (must be the worker set on the job)
(define-public (submit-milestone (job-id uint) (amount uint) (description (string-ascii 256)))
  (begin
    (asserts! (> job-id u0) (err err-invalid))
    (asserts! (> amount u0) (err err-invalid))
    (asserts! (< (len description) u257) (err err-invalid))
    (match (map-get? jobs { job-id: job-id })
      job-tuple
      (begin
        (asserts! (is-eq (get worker job-tuple) tx-sender) (err err-not-worker))
        ;; increment milestone counter for this job
        (let ((mc (default-to { count: u0 } (map-get? job-mid-counter { job-id: job-id }))))
          (let ((mid (get count mc)))
            (let ((new-mid (+ mid u1)))
              (begin
                (map-set job-mid-counter { job-id: job-id } { count: new-mid })
                (map-set milestones {job-id: job-id, mid: new-mid}
                  {
                    creator: tx-sender,
                    amount: amount,
                    description: description,
                    approved: false,
                    paid: false
                  })
                (ok new-mid))))))
      (err err-job-not-found))))

;; Client approves milestone (and trigger payout). Only client may approve.
;; This will transfer STX from contract balance to the worker if there are sufficient funds
(define-public (approve-milestone (job-id uint) (mid uint))
  (begin
    (asserts! (> job-id u0) (err err-invalid))
    (asserts! (> mid u0) (err err-invalid))
    (match (map-get? milestones {job-id: job-id, mid: mid})
      milestone
      (match (map-get? jobs { job-id: job-id })
        job-tuple
        (begin
          (asserts! (is-eq (get client job-tuple) tx-sender) (err err-not-client))
          (asserts! (not (get paid milestone)) (err err-invalid)) ;; not already paid
        (let ((amt (get amount milestone))
              (worker-pr (get creator milestone))
              (job-funded (get funded job-tuple)))
          (asserts! (>= job-funded amt) (err err-insufficient-funds))
          ;; attempt transfer from contract -> worker
          (match (stx-transfer? amt (as-contract tx-sender) worker-pr)
            transfer-ok
            (begin
              ;; mark milestone paid and update job funded
              (map-set milestones {job-id: job-id, mid: mid}
                {
                  creator: worker-pr,
                  amount: amt,
                  description: (get description milestone),
                  approved: true,
                  paid: true
                })
              (map-set jobs { job-id: job-id }
                {
                  client: (get client job-tuple),
                  worker: (get worker job-tuple),
                  price: (get price job-tuple),
                  funded: (- job-funded amt),
                  status: (if (<= (- job-funded amt) u0) "completed" "in-progress")
                })
              ;; bump worker reputation (+1)
              (match (map-get? reputation { user: worker-pr })
                rep (map-set reputation { user: worker-pr } { score: (+ (get score rep) 1) })
                (map-set reputation { user: worker-pr } { score: 1 }))
              (ok true))
            transfer-err (err err-payment-failed))))
      (err err-job-not-found))
    (err err-job-not-found))))

;; Query functions

(define-read-only (get-job (job-id uint))
  (map-get? jobs { job-id: job-id }))

(define-read-only (get-milestone (job-id uint) (mid uint))
  (map-get? milestones {job-id: job-id, mid: mid}))

(define-read-only (get-reputation (user principal))
  (map-get? reputation { user: user }))

(define-read-only (get-job-funded (job-id uint))
  (match (map-get? jobs { job-id: job-id })
    job (ok (get funded job))
    (err err-job-not-found)))

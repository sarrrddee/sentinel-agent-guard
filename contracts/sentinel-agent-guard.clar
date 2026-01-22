;; ============================================================
;; Contract: sentinel-agent-guard.clar
;; Purpose : Permission & spending guard for AI agents
;; Network : Stacks
;; ============================================================

;; -------------------------
;; ERRORS
;; -------------------------

(define-constant ERR-NOT-OWNER        (err u100))
(define-constant ERR-NOT-AUTHORIZED   (err u101))
(define-constant ERR-LIMIT-EXCEEDED   (err u102))
(define-constant ERR-AGENT-REVOKED    (err u103))
(define-constant ERR-INVALID-AMOUNT   (err u104))

;; -------------------------
;; CONFIG
;; -------------------------

(define-constant EPOCH-LENGTH u144) ;; ~1 day (144 blocks)

;; -------------------------
;; STORAGE
;; -------------------------

(define-map agents
  { owner: principal, agent: principal }
  {
    max-per-epoch: uint,
    spent-this-epoch: uint,
    epoch-start: uint,
    active: bool
  }
)

;; -------------------------
;; INTERNAL: RESET EPOCH
;; -------------------------

(define-private (refresh-epoch (record { max-per-epoch: uint, spent-this-epoch: uint, epoch-start: uint, active: bool }))
  (let ((current-height burn-block-height))
    (if (>= (- current-height (get epoch-start record)) EPOCH-LENGTH)
        (merge record {
          spent-this-epoch: u0,
          epoch-start: current-height
        })
        record
    )
  )
)

;; -------------------------
;; REGISTER AGENT
;; -------------------------

(define-public (register-agent
  (agent principal)
  (max-per-epoch uint)
)
  (begin
    (asserts! (> max-per-epoch u0) ERR-INVALID-AMOUNT)

    (map-set agents
      { owner: tx-sender, agent: agent }
      {
        max-per-epoch: max-per-epoch,
        spent-this-epoch: u0,
        epoch-start: burn-block-height,
        active: true
      }
    )

    (ok true)
  )
)

;; -------------------------
;; REVOKE AGENT
;; -------------------------

(define-public (revoke-agent (agent principal))
  (let ((record (map-get? agents { owner: tx-sender, agent: agent })))
    (match record data
      (begin
        (map-set agents
          { owner: tx-sender, agent: agent }
          (merge data { active: false })
        )
        (ok true)
      )
      ERR-NOT-AUTHORIZED
    )
  )
)

;; -------------------------
;; EXECUTE SPEND (CALLED BY AGENT)
;; -------------------------

(define-public (agent-spend
  (owner principal)
  (recipient principal)
  (amount uint)
)
  (let ((record (map-get? agents { owner: owner, agent: tx-sender })))
    (match record data
      (begin
        (asserts! (get active data) ERR-AGENT-REVOKED)
        (asserts! (> amount u0) ERR-INVALID-AMOUNT)

        (let ((updated (refresh-epoch data)))
          (asserts!
            (<= (+ (get spent-this-epoch updated) amount)
                (get max-per-epoch updated))
            ERR-LIMIT-EXCEEDED
          )

          ;; Transfer funds from owner to recipient
          (try!
            (stx-transfer? amount owner recipient)
          )

          ;; Update spent amount
          (map-set agents
            { owner: owner, agent: tx-sender }
            (merge updated {
              spent-this-epoch: (+ (get spent-this-epoch updated) amount)
            })
          )

          (ok true)
        )
      )
      ERR-NOT-AUTHORIZED
    )
  )
)

;; -------------------------
;; READ-ONLY VIEWS
;; -------------------------

(define-read-only (get-agent
  (owner principal)
  (agent principal)
)
  (map-get? agents { owner: owner, agent: agent })
)

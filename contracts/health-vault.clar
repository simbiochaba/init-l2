;; init-l2: Health Data Management Smart Contract
;; A secure, privacy-preserving platform for managing personal health information

;; Error Codes
(define-constant ERR-NOT-AUTHORIZED (err u1001))
(define-constant ERR-USER-NOT-FOUND (err u1002))
(define-constant ERR-PROVIDER-NOT-REGISTERED (err u1003))
(define-constant ERR-DATA-NOT-FOUND (err u1004))
(define-constant ERR-PERMISSION-NOT-FOUND (err u1005))
(define-constant ERR-PERMISSION-EXPIRED (err u1006))
(define-constant ERR-INVALID-PARAMETERS (err u1007))
(define-constant ERR-ALREADY-REGISTERED (err u1008))
(define-constant ERR-INSUFFICIENT-PRIVILEGES (err u1009))
(define-constant ERR-EMERGENCY-ACCESS-NOT-ENABLED (err u1010))

;; Data Structures
(define-map user-profiles 
  { user: principal }
  {
    registered: bool,
    emergency-contact: (optional principal),
    emergency-access-enabled: bool,
    encrypted-profile-url: (optional (string-utf8 256))
  }
)

(define-map healthcare-entities
  { entity: principal }
  {
    registered: bool,
    entity-name: (string-utf8 100),
    entity-type: (string-utf8 50),
    verification-status: bool,
    verification-timestamp: (optional uint)
  }
)

(define-map health-records
  { user: principal, record-id: uint }
  {
    record-type: (string-utf8 50),
    timestamp: uint,
    encrypted-data: (string-utf8 1024),
    large-data-reference: (optional (string-utf8 256)),
    data-checksum: (string-utf8 64),
    recording-entity: (optional principal)
  }
)

(define-map access-permissions
  { user: principal, accessor: principal, permission-id: uint }
  {
    granted-at: uint,
    expires-at: (optional uint),
    permitted-data-types: (list 20 (string-utf8 50)),
    revoked: bool,
    is-emergency-permission: bool
  }
)

(define-map access-audit-log
  { user: principal, log-id: uint }
  {
    accessor: principal,
    access-timestamp: uint,
    accessed-data-types: (list 20 (string-utf8 50)),
    associated-permission-id: uint
  }
)

;; Auto-incrementing ID trackers
(define-data-var next-record-id uint u0)
(define-data-var next-permission-id uint u0)
(define-data-var next-log-id uint u0)

;; Private Utility Functions
(define-private (increment-record-id)
  (let ((current-id (var-get next-record-id)))
    (var-set next-record-id (+ current-id u1))
    current-id
  )
)

(define-private (is-user-registered (user principal))
  (default-to false (get registered (map-get? user-profiles { user: user })))
)

(define-private (is-entity-registered (entity principal))
  (default-to false (get registered (map-get? healthcare-entities { entity: entity })))
)

;; Public Functions
(define-public (register-user (encrypted-profile-url (optional (string-utf8 256))))
  (let ((user tx-sender))
    (asserts! (not (is-user-registered user)) ERR-ALREADY-REGISTERED)
    
    (map-set user-profiles
      { user: user }
      {
        registered: true,
        emergency-contact: none,
        emergency-access-enabled: false,
        encrypted-profile-url: encrypted-profile-url
      }
    )
    (ok true)
  )
)

(define-public (register-healthcare-entity 
  (entity-name (string-utf8 100)) 
  (entity-type (string-utf8 50))
)
  (let ((entity tx-sender))
    (asserts! (not (is-entity-registered entity)) ERR-ALREADY-REGISTERED)
    
    (map-set healthcare-entities
      { entity: entity }
      {
        registered: true,
        entity-name: entity-name,
        entity-type: entity-type,
        verification-status: false,
        verification-timestamp: none
      }
    )
    (ok true)
  )
)

(define-public (add-health-record 
  (record-type (string-utf8 50))
  (encrypted-data (string-utf8 1024))
  (large-data-reference (optional (string-utf8 256)))
  (data-checksum (string-utf8 64))
)
  (let (
    (user tx-sender)
    (record-id (increment-record-id))
  )
    (asserts! (is-user-registered user) ERR-USER-NOT-FOUND)
    
    (map-set health-records
      { user: user, record-id: record-id }
      {
        record-type: record-type,
        timestamp: block-height,
        encrypted-data: encrypted-data,
        large-data-reference: large-data-reference,
        data-checksum: data-checksum,
        recording-entity: none
      }
    )
    (ok record-id)
  )
)

(define-public (grant-data-access 
  (accessor principal) 
  (data-types (list 20 (string-utf8 50)))
  (expiration (optional uint))
)
  (let (
    (user tx-sender)
    (permission-id (var-get next-permission-id))
  )
    (asserts! (is-user-registered user) ERR-USER-NOT-FOUND)
    (asserts! (> (len data-types) u0) ERR-INVALID-PARAMETERS)
    
    (map-set access-permissions
      { user: user, accessor: accessor, permission-id: permission-id }
      {
        granted-at: block-height,
        expires-at: expiration,
        permitted-data-types: data-types,
        revoked: false,
        is-emergency-permission: false
      }
    )
    (var-set next-permission-id (+ permission-id u1))
    (ok permission-id)
  )
)

;; More functions would be implemented similarly to preserve original logic
;; Placeholder for complex logic like emergency access, logging, etc.
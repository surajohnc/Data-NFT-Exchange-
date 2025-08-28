(define-non-fungible-token data-nft uint)

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-token-owner (err u101))
(define-constant err-token-not-found (err u102))
(define-constant err-insufficient-payment (err u103))
(define-constant err-license-expired (err u104))
(define-constant err-unauthorized-access (err u105))
(define-constant err-invalid-royalty (err u106))

(define-data-var next-token-id uint u1)
(define-data-var platform-fee-rate uint u250)

(define-map token-metadata uint {
    name: (string-utf8 50),
    description: (string-utf8 200),
    dataset-hash: (string-utf8 64),
    price: uint,
    royalty-rate: uint,
    license-duration: uint,
    creator: principal
})

(define-map license-agreements {token-id: uint, licensee: principal} {
    expiry-block: uint,
    access-rights: uint,
    payment-amount: uint,
    granted-at: uint
})

(define-map creator-earnings principal uint)
(define-map platform-earnings principal uint)

(define-read-only (get-next-token-id)
    (var-get next-token-id)
)

(define-read-only (get-token-metadata (token-id uint))
    (map-get? token-metadata token-id)
)

(define-read-only (get-license-info (token-id uint) (licensee principal))
    (map-get? license-agreements {token-id: token-id, licensee: licensee})
)

(define-read-only (get-creator-earnings (creator principal))
    (default-to u0 (map-get? creator-earnings creator))
)

(define-read-only (get-platform-earnings (account principal))
    (default-to u0 (map-get? platform-earnings account))
)

(define-read-only (is-license-valid (token-id uint) (licensee principal))
    (let ((license-data (map-get? license-agreements {token-id: token-id, licensee: licensee})))
        (match license-data
            license (> (get expiry-block license) stacks-block-height)
            false
        )
    )
)

(define-read-only (get-token-owner (token-id uint))
    (nft-get-owner? data-nft token-id)
)

(define-read-only (calculate-royalty (token-id uint) (sale-price uint))
    (match (map-get? token-metadata token-id)
        metadata (/ (* sale-price (get royalty-rate metadata)) u10000)
        u0
    )
)

(define-read-only (calculate-platform-fee (amount uint))
    (/ (* amount (var-get platform-fee-rate)) u10000)
)

(define-public (mint-data-nft 
    (name (string-utf8 50))
    (description (string-utf8 200))
    (dataset-hash (string-utf8 64))
    (price uint)
    (royalty-rate uint)
    (license-duration uint)
)
    (let ((token-id (var-get next-token-id)))
        (asserts! (<= royalty-rate u5000) err-invalid-royalty)
        (try! (nft-mint? data-nft token-id tx-sender))
        (map-set token-metadata token-id {
            name: name,
            description: description,
            dataset-hash: dataset-hash,
            price: price,
            royalty-rate: royalty-rate,
            license-duration: license-duration,
            creator: tx-sender
        })
        (var-set next-token-id (+ token-id u1))
        (ok token-id)
    )
)

(define-public (purchase-license (token-id uint))
    (let (
        (metadata (unwrap! (map-get? token-metadata token-id) err-token-not-found))
        (price (get price metadata))
        (creator (get creator metadata))
        (royalty-amount (calculate-royalty token-id price))
        (platform-fee (calculate-platform-fee price))
        (creator-payment (- price (+ royalty-amount platform-fee)))
        (expiry-block (+ stacks-block-height (get license-duration metadata)))
    )
        (try! (stx-transfer? price tx-sender (as-contract tx-sender)))
        (try! (as-contract (stx-transfer? creator-payment tx-sender creator)))
        (try! (as-contract (stx-transfer? platform-fee tx-sender contract-owner)))
        (map-set license-agreements 
            {token-id: token-id, licensee: tx-sender}
            {
                expiry-block: expiry-block,
                access-rights: u1,
                payment-amount: price,
                granted-at: stacks-block-height
            }
        )
        (map-set creator-earnings creator 
            (+ (get-creator-earnings creator) creator-payment))
        (map-set platform-earnings contract-owner 
            (+ (get-platform-earnings contract-owner) platform-fee))
        (ok true)
    )
)

(define-public (transfer-nft (token-id uint) (sender principal) (recipient principal))
    (begin
        (asserts! (is-eq tx-sender sender) err-not-token-owner)
        (try! (nft-transfer? data-nft token-id sender recipient))
        (ok true)
    )
)

(define-public (update-token-price (token-id uint) (new-price uint))
    (let ((metadata (unwrap! (map-get? token-metadata token-id) err-token-not-found)))
        (asserts! (is-eq tx-sender (unwrap! (nft-get-owner? data-nft token-id) err-token-not-found)) err-not-token-owner)
        (map-set token-metadata token-id 
            (merge metadata {price: new-price}))
        (ok true)
    )
)

(define-public (extend-license (token-id uint) (additional-blocks uint))
    (let (
        (current-license (unwrap! (map-get? license-agreements {token-id: token-id, licensee: tx-sender}) err-token-not-found))
        (metadata (unwrap! (map-get? token-metadata token-id) err-token-not-found))
        (extension-price (/ (* (get price metadata) additional-blocks) (get license-duration metadata)))
        (creator (get creator metadata))
        (royalty-amount (calculate-royalty token-id extension-price))
        (platform-fee (calculate-platform-fee extension-price))
        (creator-payment (- extension-price (+ royalty-amount platform-fee)))
        (new-expiry (+ (get expiry-block current-license) additional-blocks))
    )
        (try! (stx-transfer? extension-price tx-sender (as-contract tx-sender)))
        (try! (as-contract (stx-transfer? creator-payment tx-sender creator)))
        (try! (as-contract (stx-transfer? platform-fee tx-sender contract-owner)))
        (map-set license-agreements 
            {token-id: token-id, licensee: tx-sender}
            (merge current-license {expiry-block: new-expiry}))
        (map-set creator-earnings creator 
            (+ (get-creator-earnings creator) creator-payment))
        (ok true)
    )
)

(define-public (revoke-license (token-id uint) (licensee principal))
    (begin
        (asserts! (is-eq tx-sender (unwrap! (nft-get-owner? data-nft token-id) err-token-not-found)) err-not-token-owner)
        (map-delete license-agreements {token-id: token-id, licensee: licensee})
        (ok true)
    )
)

(define-public (withdraw-earnings)
    (let ((earnings (get-creator-earnings tx-sender)))
        (asserts! (> earnings u0) err-insufficient-payment)
        (try! (as-contract (stx-transfer? earnings tx-sender tx-sender)))
        (map-delete creator-earnings tx-sender)
        (ok earnings)
    )
)

(define-public (set-platform-fee (new-fee-rate uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (<= new-fee-rate u1000) err-invalid-royalty)
        (var-set platform-fee-rate new-fee-rate)
        (ok true)
    )
)

(define-read-only (get-dataset-access (token-id uint))
    (let ((license (map-get? license-agreements {token-id: token-id, licensee: tx-sender})))
        (match license
            license-data (if (> (get expiry-block license-data) stacks-block-height)
                            (map-get? token-metadata token-id)
                            none)
            none
        )
    )
)

(define-public (pause-license (token-id uint) (licensee principal))
    (begin
        (asserts! (is-eq tx-sender (unwrap! (nft-get-owner? data-nft token-id) err-token-not-found)) err-not-token-owner)
        (let ((current-license (unwrap! (map-get? license-agreements {token-id: token-id, licensee: licensee}) err-token-not-found)))
            (map-set license-agreements 
                {token-id: token-id, licensee: licensee}
                (merge current-license {access-rights: u0}))
            (ok true)
        )
    )
)

(define-public (resume-license (token-id uint) (licensee principal))
    (begin
        (asserts! (is-eq tx-sender (unwrap! (nft-get-owner? data-nft token-id) err-token-not-found)) err-not-token-owner)
        (let ((current-license (unwrap! (map-get? license-agreements {token-id: token-id, licensee: licensee}) err-token-not-found)))
            (map-set license-agreements 
                {token-id: token-id, licensee: licensee}
                (merge current-license {access-rights: u1}))
            (ok true)
        )
    )
)

(define-read-only (get-license-status (token-id uint) (licensee principal))
    (let ((license (map-get? license-agreements {token-id: token-id, licensee: licensee})))
        (match license
            license-data {
                active: (and (> (get expiry-block license-data) stacks-block-height) (> (get access-rights license-data) u0)),
                expires-at: (get expiry-block license-data),
                access-rights: (get access-rights license-data)
            }
            {active: false, expires-at: u0, access-rights: u0}
        )
    )
)

(define-public (emergency-pause)
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (var-set platform-fee-rate u10000)
        (ok true)
    )
)

(define-public (emergency-unpause)
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (var-set platform-fee-rate u250)
        (ok true)
    )
)

(define-read-only (get-contract-stats)
    (ok {
        total-tokens: (- (var-get next-token-id) u1),
        platform-fee-rate: (var-get platform-fee-rate),
        contract-owner: contract-owner
    })
)

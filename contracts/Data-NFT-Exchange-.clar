(define-non-fungible-token data-nft uint)

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-token-owner (err u101))
(define-constant err-token-not-found (err u102))
(define-constant err-insufficient-payment (err u103))
(define-constant err-license-expired (err u104))
(define-constant err-unauthorized-access (err u105))
(define-constant err-invalid-royalty (err u106))
(define-constant err-bulk-discount (err u107))
(define-constant err-invalid-tier (err u108))
(define-constant err-tier-not-found (err u109))
(define-constant err-downgrade-not-allowed (err u110))

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

(define-map subscription-tiers {token-id: uint, tier-level: uint} {
    tier-name: (string-utf8 20),
    price: uint,
    duration: uint,
    features: uint
})

(define-map active-subscriptions {token-id: uint, subscriber: principal} {
    tier-level: uint,
    expiry-block: uint,
    auto-renew: bool,
    started-at: uint
})

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

(define-read-only (get-bulk-discount (quantity uint))
    (if (>= quantity u5)
        u1000
        u0
    )
)

(define-read-only (quote-license-price (token-id uint) (quantity uint))
    (match (map-get? token-metadata token-id)
        metadata
            (let (
                (unit-price (get price metadata))
                (discount-rate (get-bulk-discount quantity))
                (total-price (* unit-price quantity))
                (discount-amount (/ (* total-price discount-rate) u10000))
                (discounted-price (- total-price discount-amount))
                (platform-fee (calculate-platform-fee discounted-price))
                (royalty-amount (calculate-royalty token-id discounted-price))
                (creator-payment (- discounted-price (+ platform-fee royalty-amount)))
            )
                (ok {
                    unit-price: unit-price,
                    quantity: quantity,
                    discount-rate: discount-rate,
                    discount-amount: discount-amount,
                    subtotal: total-price,
                    final-price: discounted-price,
                    platform-fee: platform-fee,
                    royalty-amount: royalty-amount,
                    creator-payment: creator-payment
                })
            )
        err-token-not-found
    )
)

(define-read-only (quote-extension-price (token-id uint) (additional-blocks uint))
    (match (map-get? token-metadata token-id)
        metadata
            (let (
                (base-price (get price metadata))
                (base-duration (get license-duration metadata))
                (extension-price (/ (* base-price additional-blocks) base-duration))
                (platform-fee (calculate-platform-fee extension-price))
                (royalty-amount (calculate-royalty token-id extension-price))
                (creator-payment (- extension-price (+ platform-fee royalty-amount)))
            )
                (ok {
                    base-price: base-price,
                    base-duration: base-duration,
                    additional-blocks: additional-blocks,
                    extension-price: extension-price,
                    platform-fee: platform-fee,
                    royalty-amount: royalty-amount,
                    creator-payment: creator-payment
                })
            )
        err-token-not-found
    )
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

(define-public (purchase-with-bulk-discount (token-id uint) (quantity uint))
    (let (
        (metadata (unwrap! (map-get? token-metadata token-id) err-token-not-found))
        (unit-price (get price metadata))
        (discount-rate (get-bulk-discount quantity))
        (total-price (* unit-price quantity))
        (discount-amount (/ (* total-price discount-rate) u10000))
        (final-price (- total-price discount-amount))
        (creator (get creator metadata))
        (platform-fee (calculate-platform-fee final-price))
        (creator-payment (- final-price platform-fee))
        (expiry-block (+ stacks-block-height (get license-duration metadata)))
    )
        (asserts! (>= quantity u1) err-bulk-discount)
        (try! (stx-transfer? final-price tx-sender (as-contract tx-sender)))
        (try! (as-contract (stx-transfer? creator-payment tx-sender creator)))
        (try! (as-contract (stx-transfer? platform-fee tx-sender contract-owner)))
        (map-set license-agreements 
            {token-id: token-id, licensee: tx-sender}
            {
                expiry-block: expiry-block,
                access-rights: quantity,
                payment-amount: final-price,
                granted-at: stacks-block-height
            }
        )
        (map-set creator-earnings creator 
            (+ (get-creator-earnings creator) creator-payment))
        (ok final-price)
    )
)

(define-public (create-subscription-tier 
    (token-id uint)
    (tier-level uint)
    (tier-name (string-utf8 20))
    (price uint)
    (duration uint)
    (features uint)
)
    (begin
        (asserts! (is-eq tx-sender (unwrap! (nft-get-owner? data-nft token-id) err-token-not-found)) err-not-token-owner)
        (asserts! (and (>= tier-level u1) (<= tier-level u3)) err-invalid-tier)
        (map-set subscription-tiers 
            {token-id: token-id, tier-level: tier-level}
            {
                tier-name: tier-name,
                price: price,
                duration: duration,
                features: features
            }
        )
        (ok true)
    )
)

(define-public (subscribe-to-tier (token-id uint) (tier-level uint))
    (let (
        (tier-data (unwrap! (map-get? subscription-tiers {token-id: token-id, tier-level: tier-level}) err-tier-not-found))
        (metadata (unwrap! (map-get? token-metadata token-id) err-token-not-found))
        (tier-price (get price tier-data))
        (tier-duration (get duration tier-data))
        (creator (get creator metadata))
        (platform-fee (calculate-platform-fee tier-price))
        (creator-payment (- tier-price platform-fee))
        (expiry-block (+ stacks-block-height tier-duration))
    )
        (try! (stx-transfer? tier-price tx-sender (as-contract tx-sender)))
        (try! (as-contract (stx-transfer? creator-payment tx-sender creator)))
        (try! (as-contract (stx-transfer? platform-fee tx-sender contract-owner)))
        (map-set active-subscriptions
            {token-id: token-id, subscriber: tx-sender}
            {
                tier-level: tier-level,
                expiry-block: expiry-block,
                auto-renew: false,
                started-at: stacks-block-height
            }
        )
        (map-set creator-earnings creator 
            (+ (get-creator-earnings creator) creator-payment))
        (map-set platform-earnings contract-owner 
            (+ (get-platform-earnings contract-owner) platform-fee))
        (ok true)
    )
)

(define-public (upgrade-subscription (token-id uint) (new-tier-level uint))
    (let (
        (current-sub (unwrap! (map-get? active-subscriptions {token-id: token-id, subscriber: tx-sender}) err-token-not-found))
        (current-tier (get tier-level current-sub))
        (new-tier-data (unwrap! (map-get? subscription-tiers {token-id: token-id, tier-level: new-tier-level}) err-tier-not-found))
        (metadata (unwrap! (map-get? token-metadata token-id) err-token-not-found))
        (remaining-blocks (- (get expiry-block current-sub) stacks-block-height))
        (upgrade-price (get price new-tier-data))
        (creator (get creator metadata))
        (platform-fee (calculate-platform-fee upgrade-price))
        (creator-payment (- upgrade-price platform-fee))
        (new-expiry (+ stacks-block-height (get duration new-tier-data)))
    )
        (asserts! (> new-tier-level current-tier) err-downgrade-not-allowed)
        (asserts! (> (get expiry-block current-sub) stacks-block-height) err-license-expired)
        (try! (stx-transfer? upgrade-price tx-sender (as-contract tx-sender)))
        (try! (as-contract (stx-transfer? creator-payment tx-sender creator)))
        (try! (as-contract (stx-transfer? platform-fee tx-sender contract-owner)))
        (map-set active-subscriptions
            {token-id: token-id, subscriber: tx-sender}
            {
                tier-level: new-tier-level,
                expiry-block: new-expiry,
                auto-renew: (get auto-renew current-sub),
                started-at: stacks-block-height
            }
        )
        (map-set creator-earnings creator 
            (+ (get-creator-earnings creator) creator-payment))
        (ok true)
    )
)

(define-public (toggle-auto-renew (token-id uint))
    (let (
        (current-sub (unwrap! (map-get? active-subscriptions {token-id: token-id, subscriber: tx-sender}) err-token-not-found))
    )
        (map-set active-subscriptions
            {token-id: token-id, subscriber: tx-sender}
            (merge current-sub {auto-renew: (not (get auto-renew current-sub))})
        )
        (ok true)
    )
)

(define-read-only (get-subscription-tier (token-id uint) (tier-level uint))
    (map-get? subscription-tiers {token-id: token-id, tier-level: tier-level})
)

(define-read-only (get-active-subscription (token-id uint) (subscriber principal))
    (map-get? active-subscriptions {token-id: token-id, subscriber: subscriber})
)

(define-read-only (is-subscription-active (token-id uint) (subscriber principal))
    (match (map-get? active-subscriptions {token-id: token-id, subscriber: subscriber})
        sub-data (> (get expiry-block sub-data) stacks-block-height)
        false
    )
)

(define-read-only (get-subscriber-tier-level (token-id uint) (subscriber principal))
    (match (map-get? active-subscriptions {token-id: token-id, subscriber: subscriber})
        sub-data (if (> (get expiry-block sub-data) stacks-block-height)
                    (some (get tier-level sub-data))
                    none)
        none
    )
)

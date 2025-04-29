;; DFX-010 Digital Financial Exchange Token Trait
(define-trait dfx-010-trait
    (
        ;; Move tokens from sender to recipient
        (move-funds (uint principal principal) (response bool uint))
        ;; Query the token holdings of account-owner
        (query-holdings (principal) (response uint uint))
        ;; Query the full token issuance
        (query-total-issuance () (response uint uint))
        ;; Query the token precision
        (query-precision () (response uint uint))
        ;; Query the token identifier
        (query-identifier () (response (string-ascii 32) uint))
        ;; Query the token ticker
        (query-ticker () (response (string-ascii 32) uint))
        ;; Query the token metadata URI
        (query-metadata-uri () (response (optional (string-utf8 256)) uint))
    )
)
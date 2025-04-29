# Financial Oracle System

A comprehensive blockchain-based oracle system for financial data management, currency conversion, and rate calculations on the Stacks network. The system provides advanced tiered calculations with adjustment mechanisms, real-time currency conversion, and detailed reporting capabilities.

## Overview

The Financial Oracle System consists of two main components:

1. **Financial Oracle Contract (`financial-oracle.clar`)**: A smart contract that provides real-time financial data, currency conversions, rate calculations, and comprehensive reporting.

2. **DFX-010 Token Trait (`dfx-token-trait.clar`)**: A standardized trait definition for fungible tokens in the ecosystem, ensuring compatibility and interoperability.

## Features

### Financial Oracle Contract

- **Real-time forex rate management**: Track and update exchange rates for multiple currencies
- **Tiered calculation system**: Process graduated rates based on input values
- **Adjustment mechanism**: Apply and manage adjustments with approval workflows
- **Comprehensive user profiles**: Track user activity, applied adjustments, and transaction history
- **Rebate processing**: Issue and track rebates with proper accounting
- **Detailed reporting**: Generate period reports and calculate net obligations

### DFX-010 Token Trait

- **Standardized token interface**: Ensures compatibility across the ecosystem
- **Complete token functionality**: Includes transfers, balance queries, and metadata
- **Extended metadata support**: Access to token identifiers and additional information

## Technical Details

### Financial Oracle Contract

The contract maintains several data structures:

- **Forex rates**: Currency exchange rates with timestamps
- **Calculation tiers**: Graduated rate structures for different calculation types
- **Adjustment factors**: Configurable adjustments with optional verification
- **User profiles**: Comprehensive tracking of user activities and applied adjustments

### DFX-010 Token Trait

The trait defines the standard interface that compatible tokens must implement:

- `move-funds`: Transfer tokens between accounts
- `query-holdings`: Check token balance for an account
- `query-total-issuance`: Get total supply of tokens
- `query-precision`: Get token decimal precision
- `query-identifier`: Get token name
- `query-ticker`: Get token symbol
- `query-metadata-uri`: Get token URI for additional metadata

## Usage Examples

### Updating Forex Rates

```clarity
(contract-call? .financial-oracle update-forex-rate "USD" u100000000)
```

### Converting Currency

```clarity
;; Convert 100 USD to EUR
(contract-call? .financial-oracle convert-currency u100 "USD" "EUR")
```

### Submitting an Adjustment Request

```clarity
(contract-call? .financial-oracle submit-adjustment-request "TAX_EXEMPT" u5000)
```

### Generating a Period Report

```clarity
(contract-call? .financial-oracle generate-period-report tx-sender u2023)
```

## Installation

1. Clone this repository
2. Deploy the contracts to the Stacks blockchain using Clarinet or another Stacks deployment tool

```bash
clarinet deploy --anchor-block-only financial-oracle
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details.
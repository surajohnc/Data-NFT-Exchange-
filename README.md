# 📊 Data NFT Exchange

> 🚀 **Empowering individuals to monetize their data while enabling researchers and businesses to access verified, privacy-preserving datasets.**

A revolutionary smart contract platform built on Stacks that transforms how we handle data ownership, licensing, and monetization. Turn your valuable datasets into NFTs and earn royalties from their usage! 🎯

## 🌟 Features

### 🏗️ Core Functionality
- **🎨 Data NFT Minting**: Transform datasets into NFTs with customizable licensing terms
- **💰 Smart Licensing**: Automated license agreements with time-based expiration
- **💸 Royalty System**: Automatic royalty distribution to original data creators
- **🔄 License Management**: Extend, pause, resume, or revoke data access
- **📈 Earnings Tracking**: Track creator and platform earnings separately

### 🛡️ Security & Control
- **⏯️ Emergency Controls**: Platform-level pause/unpause functionality
- **👥 Access Management**: Granular control over data access rights
- **🔐 Owner Verification**: Only NFT owners can manage licensing terms
- **💎 Secure Transfers**: Safe NFT transfer with proper ownership validation

## 🚀 Getting Started

### Prerequisites
- [Clarinet](https://docs.hiro.so/stacks/clarinet) installed
- Basic understanding of Clarity smart contracts
- Stacks wallet for interaction

### Installation
```bash
git clone https://github.com/your-username/Data-NFT-Exchange
cd Data-NFT-Exchange
clarinet check
```

## 📋 Usage Guide

### 1. 🎨 Minting a Data NFT
```clarity
(contract-call? .Data-NFT-Exchange- mint-data-nft 
    u"Consumer Survey Data Q1 2024"           ;; name
    u"Demographics and preferences survey"     ;; description  
    u"sha256:abc123..."                       ;; dataset hash
    u1000000                                  ;; price in microSTX
    u500                                      ;; 5% royalty rate
    u144                                      ;; license duration in blocks (~1 day)
)
```

### 2. 💳 Purchasing a License
```clarity
(contract-call? .Data-NFT-Exchange- purchase-license u1)
```

### 3. 🔍 Checking License Status
```clarity
(contract-call? .Data-NFT-Exchange- get-license-status u1 'SP1ABC...)
```

### 4. 💰 Withdrawing Earnings
```clarity
(contract-call? .Data-NFT-Exchange- withdraw-earnings)
```

## 🏗️ Contract Architecture

### 📊 Data Structures

#### Token Metadata
```clarity
{
    name: (string-utf8 50),
    description: (string-utf8 200),
    dataset-hash: (string-utf8 64),
    price: uint,
    royalty-rate: uint,
    license-duration: uint,
    creator: principal
}
```

#### License Agreements
```clarity
{
    expiry-block: uint,
    access-rights: uint,
    payment-amount: uint,
    granted-at: uint
}
```

### 🎛️ Key Functions

| Function | Description | Access |
|----------|-------------|---------|
| `mint-data-nft` | Create new data NFT | Public |
| `purchase-license` | Buy access to dataset | Public |
| `extend-license` | Extend existing license | Licensee |
| `revoke-license` | Remove access rights | NFT Owner |
| `update-token-price` | Change license price | NFT Owner |
| `withdraw-earnings` | Claim accumulated earnings | Public |

## 💼 Business Model

### 💰 Fee Structure
- **Platform Fee**: 2.5% of each transaction
- **Creator Royalty**: Up to 50% (set per NFT)
- **License Pricing**: Set by data owners

### 📈 Revenue Streams
1. **Platform Fees**: Sustainable platform operation
2. **Creator Royalties**: Ongoing income for data providers
3. **License Extensions**: Additional revenue from extended usage

## 🛠️ Development

### Running Tests
```bash
npm install
npm test
```

### Contract Deployment
```bash
clarinet integrate
clarinet deploy --testnet
```

### Local Development
```bash
clarinet console
```

## 🔐 Security Features

- ✅ Input validation and sanitization
- ✅ Ownership verification for all operations
- ✅ Royalty rate limits (max 50%)
- ✅ Emergency pause functionality
- ✅ Safe arithmetic operations
- ✅ Proper error handling

## 🌍 Use Cases

### 🎯 For Data Creators
- **📱 App Developers**: Monetize user behavior data
- **🏥 Healthcare**: License anonymized medical research data
- **🏪 Retailers**: Share customer insights data
- **📊 Survey Companies**: Sell demographic datasets

### 🔬 For Data Consumers
- **🧪 Researchers**: Access verified datasets for studies
- **🤖 AI Companies**: Train models with quality data
- **📈 Market Analysts**: Purchase consumer trend data
- **🏛️ Government**: Access citizen feedback data

## 📝 Error Codes

| Code | Description |
|------|-------------|
| u100 | Owner only operation |
| u101 | Not token owner |
| u102 | Token not found |
| u103 | Insufficient payment |
| u104 | License expired |
| u105 | Unauthorized access |
| u106 | Invalid royalty rate |

## 🤝 Contributing

We welcome contributions! Please see our contributing guidelines and code of conduct.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

**🚀 Ready to revolutionize data ownership? Start minting your data NFTs today!** 

*Made with ❤️ for the decentralized data economy*

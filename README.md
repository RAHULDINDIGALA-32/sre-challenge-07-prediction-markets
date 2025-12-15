# 🔮 SRE Challenge 07 — Prediction Markets

A full-stack Web3 project built as part of **SpeedRunEthereum Challenge 07**.

This challenge implements a **fully collateralized, on-chain prediction market** where users trade ERC20 outcome tokens that represent probabilities of real-world events.

Unlike AMM-based DEXs, this protocol uses **linear probability pricing**, **token locking**, and **oracle-based resolution** to guarantee fair settlement and deterministic payouts.

---

## 🚀 Live Demo

- **Frontend (Vercel):** https://sre-challenge-07-prediction-markets.vercel.app/
- **Prediction Market Contract (Sepolia):** `0x6388B10880fea7E104763790F8302e37742513b2`  
- **YES Token (Sepolia):** `0xf7D9e6b468e24733a45fd0771e1D3E002943b3DD`  
- **NO Token (Sepolia):** `0x6565d93176969c075a6332cdB7DE451040AD56BB`  
- **Block Explorer:** https://sepolia.etherscan.io/address/0x6388B10880fea7E104763790F8302e37742513b2

---

## 🧱 Tech Stack

### 🖥 Smart Contracts

- Solidity `^0.8.x`
- Hardhat
- Sepolia Testnet
- `PredictionMarketToken.sol` - Customized OpenZeppelin ERC20
- `PredictionMarket.sol` - A decentralized, ETH-collateralized binary prediction market
- Oracle-driven outcome resolution
- Fully collateralized settlement
- Burn-on-redeem mechanics

### 🎨 Frontend (Scaffold-ETH 2)

- Next.js 13 (App Router)
- React
- TypeScript
- TailwindCSS
- Wagmi + Viem
- RainbowKit
- Scaffold-ETH 2 Debug Panel
- Deployment on Vercel

---

## 🎯 What This Market Does

This project implements a **binary prediction market**:

- Outcomes: **YES / NO**
- Each outcome is an **ERC20 token**
- Tokens represent claims on a fixed collateral pool
- Prices represent **probabilities**
- All payouts are **fully collateralized**

There is **no leverage, no debt, and no fractional reserve risk**.

---

## 🧠 Core Design Principles

- **Price = Probability**
- **Fully collateralized payouts**
- **ERC20 outcome tokens**
- **Oracle-based finality**
- **Locked liquidity for market bootstrapping**
- **Trustless redemption via token burning**

---

## 🔒 Token Lock Mechanism (Initial Probability)

To bootstrap a market with a realistic starting probability, the protocol **locks outcome tokens inside the market contract**, simulating early demand.

### 🧮 Example

Assume:
- 100 YES tokens minted
- 100 NO tokens minted
- Target probability = **60% YES**
- Locked portion = **10% of total supply**

#### Locked Token Calculation

```solidity
lockedYes = 100 × 60% × 10% × 2 = 12

lockedNo  = 100 × 40% × 10% × 2 = 8
```

Result:
- 12 YES locked
- 8 NO locked
- 88 YES + 92 NO available for trading

Initial Probability:
```solidity
probabilityYes = 12 / (12 + 8) = 60
```

This guarantees the market starts with the intended odds before any trades occur.

---

#### 📈 Pricing Model (Linear Probability Pricing)

Prices are derived from how many tokens have been sold for each outcome.
```solidity
probabilityYes =  (tokenSoldYes + tokenLockedYes) / (tokenLockedYes + tokenLockedNo  + tokenSoldYes + tokenSoldNo)
```

💰 Buy Price Formula
```solidity
priceYes (in ETH) = initialTokenValue × probabilityYes × amountOfYesTokens
```

This pricing model creates a volume discount:
**Buying more tokens in one transaction gives a better average price — the opposite of traditional DeFi slippage 😎**

---

## ⚠️ Pricing Quirk (Important!)

Unlike constant-product AMMs:

- Large buys **reduce average price**
- Probability moves **linearly**
- No `x * y = k`
- No impermanent loss
- No hidden leverage

This makes the math:

- Simple  
- Deterministic  
- Fully explainable on-chain  

---

## 🏆 Oracle Resolution & Settlement

Once the oracle resolves the outcome:

- Winning outcome tokens can be redeemed for **ETH**
- Losing tokens become **worthless**
- Winning tokens are **burned on redemption**
- ETH is paid from the **collateral pool**

This guarantees:

- No double claims  
- No under-collateralization  
- No trusted intermediaries  

---

## 🎮 Frontend dApp

The UI allows users to:

- Connect wallet
- Buy **YES / NO** tokens
- Sell tokens back to the market
- Observe real-time probability changes
- Inspect locked liquidity
- Redeem winning tokens after resolution
- Debug contracts via **Scaffold-ETH 2**
- Inspect transactions on **Etherscan**

---

## 📐 Learning Outcomes

By completing this challenge, you learn:

- How prediction markets discover probabilities
- How ERC20 outcome tokens work
- Why token locking stabilizes early markets
- How to price probabilities on-chain
- Why linear pricing differs from AMMs
- How prediction markets trading mechanism works
- How oracle trust assumptions affect settlement
- How to design fully collateralized financial systems
- How to build production-grade Web3 UIs
- How to deploy full-stack dApps to **Sepolia + Vercel**

---

## 🎓 Part of SpeedRunEthereum

This project is part of:

🏃 **SpeedRunEthereum — Challenge 07: Prediction Markets**  
https://speedrunethereum.com/challenge/prediction-markets  

Built using **Scaffold-ETH 2**, the modern full-stack Ethereum development framework.


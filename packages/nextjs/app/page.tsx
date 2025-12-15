"use client";

import Image from "next/image";
import Link from "next/link";
import type { NextPage } from "next";
import { useAccount } from "wagmi";
import { Address } from "~~/components/scaffold-eth";
import { BugAntIcon, MagnifyingGlassIcon } from "@heroicons/react/24/outline";

const Home: NextPage = () => {
  const { address: connectedAddress } = useAccount();

  return (
    <>
      <div className="flex items-center flex-col grow pt-10">
        <div className="px-5 max-w-4xl">

          {/* HEADER */}
          <h1 className="text-center">
            <span className="block text-2xl mb-2">SpeedRunEthereum</span>
            <span className="block text-4xl font-bold">
              Challenge 07 — 🔮 Prediction Market
            </span>
            <span className="block text-lg mt-2">
              Build a fully collateralized, on-chain prediction market with
              probability-based linear pricing, liquidity provisioning, and oracle resolution.
            </span>
          </h1>

          {/* CONNECTED WALLET */}
          <div className="flex justify-center items-center space-x-2 flex-col mt-6">
            <p className="my-2 font-medium text-lg">Connected Wallet:</p>
            <Address address={connectedAddress} />
          </div>

          {/* HERO IMAGE */}
          <div className="flex flex-col items-center justify-center mt-10">
            <Image
              src="/hero.png"
              width="727"
              height="231"
              alt="Prediction Market banner"
              className="rounded-xl border-4 border-primary"
            />
          </div>

          {/* CONTENT */}
          <div className="mt-10 space-y-6 text-lg">
            <p>
              🔮 In this challenge you will build a <strong>binary prediction market</strong>
              where users trade outcome tokens (<strong>YES</strong> / <strong>NO</strong>)
              that represent claims on a future event.
            </p>

            <p>The system implemented supports:</p>

            <ul className="list-disc list-inside ml-4 space-y-1">
              <li>ETH-collateralized market creation</li>
              <li>Minting YES and NO outcome tokens</li>
              <li>Probability-based dynamic pricing</li>
              <li>Liquidity provisioning and removal</li>
              <li>Oracle-driven outcome resolution</li>
              <li>Trustless redemption of winning tokens</li>
            </ul>

            <p>
              To bootstrap the market with a realistic starting probability,
              the protocol uses a <strong>token lock mechanism</strong>.
              A portion of YES and NO tokens are locked inside the market contract,
              simulating early demand and anchoring the initial odds.
            </p>
          </div>

          {/* FORMULA EXPLANATION */}
          <div className="mt-10 space-y-6 text-lg">
            <h2 className="text-2xl font-bold">🧮 Let’s See It in Action</h2>

            <p>
              Say we mint <strong>100 YES</strong> and <strong>100 NO</strong> tokens.
              We want to simulate a <strong>60% YES probability</strong> and lock
              <strong>10%</strong> of total liquidity.
            </p>

            <pre className="bg-base-200 p-4 rounded-xl overflow-auto text-sm">
{`lockedYes = 100 × 60% × 10% × 2 = 12
lockedNo  = 100 × 40% × 10% × 2 = 8`}
            </pre>

            <ul className="list-disc list-inside ml-4 space-y-1">
              <li>🔒 12 YES tokens locked</li>
              <li>🔒 8 NO tokens locked</li>
              <li>🪙 88 YES + 92 NO tokens available for trading</li>
            </ul>

            <p>
              The starting market probability becomes:
            </p>

            <pre className="bg-base-200 p-4 rounded-xl overflow-auto text-sm">
{`12 / (12 + 8) = 60% YES`}
            </pre>
          </div>

          {/* PRICE FUNCTION */}
          <div className="mt-10 space-y-6 text-lg">
            <h2 className="text-2xl font-bold">📈 How the Price Function Works (and Its Quirks)</h2>

            <p>
              This pricing model gives users a <strong>volume discount</strong> —
              the more you buy in one transaction, the better the deal.
              This is the opposite of traditional AMMs where larger trades
              suffer from slippage. 😎
            </p>

            <pre className="bg-base-200 p-4 rounded-xl overflow-auto text-sm">
{`probabilityYes =
(tokenSoldYes + tokenLockedYes)
----------------------------------------------
(tokenLockedYes + tokenLockedNo
 + tokenSoldYes + tokenSoldNo)`}
            </pre>

            <pre className="bg-base-200 p-4 rounded-xl overflow-auto text-sm">
{`priceyes (in ETH) = initialTokenValue * probabilityYes * amountOfYesTokens`}
            </pre>

            <p>
              Because the curve is linear, buying earlier (or in larger size)
              captures cheaper average probabilities — a deliberate design choice
              to encourage early liquidity.
            </p>
          </div>

          {/* CONTRACT ADDRESSES */}
          <div className="mt-10 space-y-6 text-lg">
            <p>The smart contracts were deployed on Sepolia:</p>

            <p className="font-semibold">
              Prediction Market:{" "}
              <Link
                href="https://sepolia.etherscan.io/address/0x6388B10880fea7E104763790F8302e37742513b2"
                passHref
                className="link"
              >
                0x6388B10880fea7E104763790F8302e37742513b2
              </Link>
              <br />
              YES Token:{" "}
              <Link
                href="https://sepolia.etherscan.io/address/0xf7D9e6b468e24733a45fd0771e1D3E002943b3DD"
                passHref
                className="link"
              >
                0xf7D9e6b468e24733a45fd0771e1D3E002943b3DD
              </Link>
              <br />
              NO Token:{" "}
              <Link
                href="https://sepolia.etherscan.io/address/0x6565d93176969c075a6332cdB7DE451040AD56BB"
                passHref
                className="link"
              >
                0x6565d93176969c075a6332cdB7DE451040AD56BB
              </Link>
            </p>

            <p>
              From this UI, users can:
              <br />
              🪙 Buy YES / NO outcome tokens<br />
              🔁 Sell outcome tokens back to the market<br />
              📊 Observe live probability shifts<br />
              🔒 Inspect locked liquidity<br />
              🏆 Redeem winning tokens after resolution
            </p>

            <p>
              Built using <strong>Scaffold-ETH 2, Next.js, Wagmi, Viem, RainbowKit, and Hardhat</strong>.
            </p>
          </div>

          <p className="text-center text-lg mt-16">
            <a
              href="https://speedrunethereum.com/challenge/prediction-market"
              target="_blank"
              rel="noreferrer"
              className="underline"
            >
              SpeedRunEthereum.com
            </a>
          </p>
        </div>

        {/* FOOTER */}
        <div className="grow bg-base-300 w-full mt-16 px-8 py-12">
          <div className="flex justify-center items-center gap-12 flex-col md:flex-row">
            <div className="flex flex-col bg-base-100 px-10 py-10 text-center items-center max-w-xs rounded-3xl">
              <BugAntIcon className="h-8 w-8 fill-secondary" />
              <p>
                Interact with contracts in{" "}
                <Link href="/debug" className="link">Debug Contracts</Link>.
              </p>
            </div>

            <div className="flex flex-col bg-base-100 px-10 py-10 text-center items-center max-w-xs rounded-3xl">
              <MagnifyingGlassIcon className="h-8 w-8 fill-secondary" />
              <p>
                Inspect transactions on{" "}
                <Link href="https://sepolia.etherscan.io" className="link">Etherscan</Link>.
              </p>
            </div>
          </div>
        </div>
      </div>
    </>
  );
};

export default Home;
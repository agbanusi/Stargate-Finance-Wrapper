import React, { useEffect, useState } from "react";
import { Input } from "antd";
import {
  getUSDCBalance,
  getLPBalance,
  getWithdrawPreview,
  getDepositPreview,
  getRewards,
  depositToken,
  withdrawToken,
  claimRewards,
} from "./contracts";
import "./App.css";
import { ConnectButton } from "@rainbow-me/rainbowkit";
import { useAccount, useSigner } from "wagmi";

function App() {
  const { address } = useAccount();
  const { data: signer } = useSigner();
  const [choice, setChoice] = useState(0);
  const [amount, setAmount] = useState("");
  const [preview, setPreview] = useState("");
  const choices: { [s: string]: string } = {
    "0": "Deposit",
    "1": "Withdraw",
    "2": "Claim",
  };

  const getMaxValue = async () => {
    if (choice === 0) {
      const val = await getUSDCBalance(address as string, signer);
      setAmount(val + "");
    } else if (choice === 1) {
      const val = await getLPBalance(address as string, signer);
      setAmount(val + "");
    }
  };

  const getPreview = async () => {
    if (choice === 0) {
      return await getDepositPreview(Number(amount), signer);
    } else if (choice === 1) {
      return await getWithdrawPreview(Number(amount), signer);
    } else if (choice === 2) {
      return await getRewards(signer);
    }
  };

  useEffect(() => {
    (async function () {
      const preview = await getPreview();
      console.log({ preview, address });
      setPreview(preview + "");
    })();
  }, [choice, amount]);

  const execute = async () => {
    if (choice === 0) {
      await depositToken(Number(amount), signer);
    } else if (choice === 1) {
      await withdrawToken(Number(amount), address as string, signer);
    } else if (choice === 2) {
      await claimRewards(signer);
    }
  };

  return (
    <div className="flex flex-col  items-center w-full bg-sky-950 h-screen p-2">
      <h1 className="mt-8 md:mt-16 font-bold text-xl text-white text-center">
        Stake Your USDC on Stargate and get Rewards
      </h1>
      <div className="mt-6 md:mt-20 flex w-full md:w-[50%] justify-evenly items-center">
        <button
          className={` text-white rounded p-2 w-32 border-0 border-b-4 ${
            choice === 0 ? "border-slate-400" : "border-transparent"
          }`}
          onClick={() => {
            setChoice(0);
            setAmount("");
          }}
        >
          Deposit
        </button>
        <hr className="border-2 border-slate-600 rotate-90 w-12" />
        <button
          className={` text-white rounded p-2 w-32 border-0 border-b-4 ${
            choice === 1 ? "border-slate-400" : "border-transparent"
          }`}
          onClick={() => {
            setChoice(1);
            setAmount("");
          }}
        >
          Withdraw
        </button>
        <hr className="border-2 border-slate-600 rotate-90 w-12" />
        <button
          className={` text-white rounded p-2  w-32 border-0 border-b-4  ${
            choice === 2 ? "border-slate-400" : "border-transparent"
          }`}
          onClick={() => {
            setChoice(2);
            setAmount("");
          }}
        >
          Claim
        </button>
      </div>
      <div className="mt-[60%] md:mt-[20%] w-full flex-col md:w-[50%] flex justify-center">
        {choice <= 1 && (
          <div className="w-full flex justify-center">
            <Input
              placeholder="Enter Input Amount"
              size="large"
              allowClear
              bordered={false}
              //addonAfter="USDC"
              value={amount}
              onChange={(e) => setAmount(e.target.value)}
              styles={{
                input: {
                  color: "white",
                },
              }}
              className="border-0 border-solid border-b-2 rounded-sm px-6 bg-inherit border-slate-400 w-[85%] text-white"
            />
            <button
              className="w-16 p-2 text-white bg-blue-400 rounded drop-shadow-md"
              onClick={getMaxValue}
            >
              Max
            </button>
          </div>
        )}
        <span className="text-white text-sm font-bold mt-8 text-center">
          {choice === 0
            ? `You'll get ${preview} USDC-SV tokens`
            : choice === 1
            ? `You'll burn ${preview} USDC-SV tokens`
            : `You can claim ${preview} USDC tokens as reward`}
        </span>
        {address ? (
          <button
            className="p-4 text-white bg-blue-500 rounded mt-12"
            onClick={execute}
          >
            {choices[choice]}
          </button>
        ) : (
          <div className="self-center mt-12">
            <ConnectButton accountStatus="avatar" />
          </div>
        )}
      </div>
      )
    </div>
  );
}

export default App;

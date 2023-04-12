import { ethers } from "ethers";
import IERC20 from "./artifacts/contracts/stargatewrapper.sol/IERC20.json";
import Wrapper from "./artifacts/contracts/stargatewrapper.sol/StargateWrapper.json";

const usdc = "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174";
const token = "0x3ca2b1565f43e8ed469571b28aB4f4445486070E";
const usdc_multiplier = 10 ** 6;
const multiplier = 10 ** 6;
export async function getUSDCBalance(user: string, walletProvider: any) {
  const contract = new ethers.Contract(usdc, IERC20.abi, walletProvider);
  const balance = (await contract.balanceOf(user)).toString();
  return balance / usdc_multiplier;
}

export async function approveToken(
  amount: number,
  spender: string,
  walletProvider: any
) {
  const contract = new ethers.Contract(usdc, IERC20.abi, walletProvider);
  const txn = await contract.approve(spender, amount * multiplier);
  return txn;
}

export async function getLPBalance(user: string, walletProvider: any) {
  const contract = new ethers.Contract(token, Wrapper.abi, walletProvider);
  const balance = (await contract.balanceOf(user)).toString();
  return balance / usdc_multiplier;
}

export async function getRewards(walletProvider: any) {
  const contract = new ethers.Contract(token, Wrapper.abi, walletProvider);
  const balance = (await contract.getRewards()).toString();
  console.log({ balance });
  return balance / multiplier;
}

export async function getMaxWithdraws(user: string, walletProvider: any) {
  const contract = new ethers.Contract(token, Wrapper.abi, walletProvider);
  const balance = (await contract.maxWithdraw(user)).toString();
  return balance / multiplier;
}

export async function getDepositPreview(amount: number, walletProvider: any) {
  const contract = new ethers.Contract(token, Wrapper.abi, walletProvider);
  const balance = (
    await contract.previewDeposit(amount * multiplier)
  ).toString();
  return balance / multiplier;
}

export async function getWithdrawPreview(amount: number, walletProvider: any) {
  const contract = new ethers.Contract(token, Wrapper.abi, walletProvider);
  const balance = (
    await contract.previewWithdraw(amount * multiplier)
  ).toString();
  return balance / multiplier;
}

export async function depositToken(amount: number, walletProvider: any) {
  const contract = new ethers.Contract(token, Wrapper.abi, walletProvider);
  console.log({ contract });
  const depTxn = await contract.deposit(amount * multiplier);
  return depTxn;
}

export async function withdrawToken(
  amount: number,
  to: string,
  walletProvider: any
) {
  const contract = new ethers.Contract(token, Wrapper.abi, walletProvider);
  const txn = await contract.withdraw(amount * multiplier, to);
  return txn;
}

export async function claimRewards(walletProvider: any) {
  const contract = new ethers.Contract(token, Wrapper.abi, walletProvider);
  const txn = await contract.claimRewards();
  return txn;
}

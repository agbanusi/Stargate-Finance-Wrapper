// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";

interface IFactory {
    function getPool(uint256 _poolId) external view returns (IPool);
}

interface IPool {
    function totalSupply() external view returns (uint256);
    function totalLiquidity() external view returns (uint256);
    function balanceOf(address user) external view returns (uint256);
}

interface IStargateRouter {
    struct lzTxObj {
        uint256 dstGasForCall;
        uint256 dstNativeAmount;
        bytes dstNativeAddr;
    }

    function addLiquidity(
        uint256 _poolId,
        uint256 _amountLD,
        address _to
    ) external;

    function swap(
        uint16 _dstChainId,
        uint256 _srcPoolId,
        uint256 _dstPoolId,
        address payable _refundAddress,
        uint256 _amountLD,
        uint256 _minAmountLD,
        lzTxObj memory _lzTxParams,
        bytes calldata _to,
        bytes calldata _payload
    ) external payable;

    function redeemRemote(
        uint16 _dstChainId,
        uint256 _srcPoolId,
        uint256 _dstPoolId,
        address payable _refundAddress,
        uint256 _amountLP,
        uint256 _minAmountLD,
        bytes calldata _to,
        lzTxObj memory _lzTxParams
    ) external payable;

    function instantRedeemLocal(
        uint16 _srcPoolId,
        uint256 _amountLP,
        address _to
    ) external returns (uint256);

    function factory() external view returns (address);

    function redeemLocal(
        uint16 _dstChainId,
        uint256 _srcPoolId,
        uint256 _dstPoolId,
        address payable _refundAddress,
        uint256 _amountLP,
        bytes calldata _to,
        lzTxObj memory _lzTxParams
    ) external payable;

    function sendCredits(
        uint16 _dstChainId,
        uint256 _srcPoolId,
        uint256 _dstPoolId,
        address payable _refundAddress
    ) external payable;
}


contract StargateWrapper is Ownable, ERC4626 {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;
    using Address for address;

    IStargateRouter public stargate;
    IERC20 public usdc;
    uint256 public maxAmount;
    uint256 public withdrawFee;
    uint256 public rewardIndex;
    uint16 public poolId;

    mapping(address=>uint256) userShares;
    uint256 totalShares = 0;

    event Deposit(address indexed from, uint256 amount);
    event Withdraw(address indexed to, uint256 share);
    event ClaimRewards(address indexed from, uint256 amount);

    constructor(IStargateRouter _stargate, IERC20 _usdc, uint256 _withdrawFee, uint16 _poolId) ERC4626(IERC20(_usdc)) ERC20("USDC Stargate Vault", "USDC-SV") {
        require(address(_stargate).isContract(), "StargateWrapper: invalid stargate address");
        require(address(_usdc).isContract(), "StargateWrapper: invalid wrapped token address");
        require(_withdrawFee <= 10000, "StargateWrapper: withdraw fee must be less than or equal to 10000");

        stargate = _stargate;
        usdc = _usdc;
        poolId = _poolId;
        maxAmount = type(uint256).max - 1;
        withdrawFee = _withdrawFee;

        usdc.safeApprove(address(stargate), type(uint256).max);
    }

    function setStargate(IStargateRouter _stargate) public onlyOwner{
        require(address(_stargate).isContract(), "StargateWrapper: invalid stargate address");
        stargate = _stargate;
    }

    function setWithdrawFee(uint256 _withdrawFee) public onlyOwner{
        require(_withdrawFee < 10000, "StargateWrapper: withdraw fee must be less than 10000");
        withdrawFee = _withdrawFee;
    }

    function deposit(uint256 _amount) public returns (uint256){
        require(_amount > 0, "StargateWrapper: amount must be greater than zero");
        require(_amount <= maxAmount, "StargateWrapper: amount exceeds max amount");
        
        
        uint256 shares = previewDeposit(_amount);
        uint256 fee = (_amount * withdrawFee) / 10000;
        
        usdc.safeTransferFrom(msg.sender, address(this), _amount);
        usdc.safeApprove(address(stargate), _amount);
        stargate.addLiquidity(poolId, _amount-fee, msg.sender);
        _mint(msg.sender, shares);

        emit Deposit(msg.sender, _amount);
        return shares;
    }

    // claim rewards togther with withdrawal
    function withdraw(uint256 _amount, address _to) public returns (uint256){
        require(_amount > 0, "StargateWrapper: amount must be greater than zero");
        require(_amount <= maxWithdraw(msg.sender), "StargateWrapper: withdraw more than max");
        
        uint256 fee = (_amount * withdrawFee) / 10000;
        uint256 shares = previewWithdraw(_amount);
        require(shares > 0, "Shares should be greater than 0");

        _burn(msg.sender, shares);
        stargate.instantRedeemLocal(poolId, _amount + fee, address(this));
        usdc.safeTransfer(_to, _amount);
        
        emit Withdraw(_to, shares);
        return shares;
    }
    
    function previewDeposit(uint256 _amount) public view override returns (uint256) {
        uint256 fee = (_amount * withdrawFee) / 10000;
        return _convertToShares(_amount - fee, Math.Rounding.Down);
    }


    function previewWithdraw(uint256 _amount) public view override returns (uint256) {
        uint256 fee = (_amount * withdrawFee) / 10000;
        return _convertToShares(_amount + fee, Math.Rounding.Up);
    }
    
    function maxWithdraw(address owner) public view override returns (uint256) {
        uint256 fee = (balanceOf(owner) * withdrawFee) / 10000;
        return _convertToAssets(balanceOf(owner) - fee, Math.Rounding.Down);
    }

    function maxRedeem(address owner) public view override returns (uint256) {
        uint256 fee = (balanceOf(owner) * withdrawFee) / 10000;
        return balanceOf(owner) - fee;
    }

    // To calculate rewards, u have to know how withdrawal is done.
    // withdraw + reward = total Liquidity * amount / total supply, and total liquidity is total Supply + fees reward
    // withdraw + reward = _amount + fee * amount/totalSupply
    // reward can be taken as fee * amount / totalSupply where fee is total liquidity - total supply
    // total rewards is then fee * total balance of vault / total supply
    // since it is a vault, user reward is balance/supply *total rewards
    // we can then withdraw user rewards but recall, withdrawal is calculated as excess to add reward fees and since we are withdrawaing only rewards, this would lead to over withdrawal
    // what we do is reduce the reward by the factor of increase ie liquidity/supply, so real reward becomes reward * supply/liquidity;
    function getRewards() public view returns (uint256) {
        address factory = stargate.factory();
        IPool pool = IFactory(factory).getPool(poolId);
        uint256 totalRewards = (pool.balanceOf(address(this)) * (pool.totalLiquidity() - pool.totalSupply()))/ pool.totalSupply();
        return (totalRewards * balanceOf(msg.sender)) * pool.totalSupply() / (totalSupply() * pool.totalLiquidity()) ; //avoid overshooting of rewards by supply * liquidity * rewardAmount as withdraw is always liqui/supply * withdrawAmount;
    }

    function claimRewards() external returns (uint256) {
        uint256 rewards = getRewards();
        return withdraw(rewards, msg.sender);
    }
}
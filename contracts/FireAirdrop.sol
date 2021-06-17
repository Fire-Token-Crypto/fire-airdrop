// SPDX-License-Identifier: MIT

pragma solidity ^0.8.5;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract FireAirdrop is Ownable, ReentrancyGuard {
    uint256 fee = 0.1 ether;

    // Event to express all the ERC20 sent
    event MultiSendToken(address token, uint256 amount);
    // Event to express all the ETH sent
    event MultiSendEth(uint256 amount);
    // Event to express a ERC20 transfer to one address
    event AutoMultiSendToken(address token, uint256 amount);
    // Event to express a ETH transfer to one address
    event AutoMultiSendEth(uint256 amount);
    // Event to express when the owner of the contract retrieves the funds
    event ClaimedTokens(
        address indexed token,
        address payable indexed ownerPayable,
        uint256 amount
    );
    event ClaimedEther(address payable indexed ownerPayable, uint256 amount);

    // Helpers

    modifier validLists(uint256 _beneficiariesLength, uint256 _balancesLength) {
        require(_beneficiariesLength > 0, "FireAirdrop: No beneficiaries sent");
        require(
            _beneficiariesLength == _balancesLength,
            "FireAirdrop: Different arrays lengths"
        );
        _;
    }

    modifier hasFee(uint256 _ethToDistribute) {
        if (_msgSender() != owner())
            require(
                msg.value - _ethToDistribute >= fee,
                "FireAidrop: You must pay a fee"
            );
        _;
    }

    function _pay(address payable _address, uint256 amount) private {
        (bool success, ) = _address.call{value: amount}("");
        require(
            success,
            "Address: unable to send value, recipient may have reverted"
        );
    }

    function _checkTotal(uint256 _total) private pure {
        require(_total == 0, "FireAirdrop: Wrong amount of total");
    }

    receive() external payable {}

    // Airdrop Functions

    function multiSendToken(
        IERC20 _token,
        address[] calldata _beneficiaries,
        uint256[] calldata _balances,
        uint256 _total
    )
        external
        payable
        hasFee(0)
        validLists(_beneficiaries.length, _balances.length)
        nonReentrant()
    {
        uint256 total = _total;

        require(
            _token.transferFrom(_msgSender(), address(this), total),
            "FireAirdrop: Couldn't transfer tokens to contract"
        );

        for (uint256 i = 0; i < _beneficiaries.length; i++) {
            require(
                _token.transfer(_beneficiaries[i], _balances[i]),
                "FireAirdrop: Couldn't transfer tokens to user"
            );
            total = total - _balances[i];
        }
        _checkTotal(total);
        emit MultiSendToken(address(_token), _total);
    }

    function multiSendEth(
        address payable[] calldata _beneficiaries,
        uint256[] calldata _balances,
        uint256 _total
    )
        external
        payable
        hasFee(_total)
        validLists(_beneficiaries.length, _balances.length)
        nonReentrant()
    {
        uint256 total = _total;

        for (uint256 i = 0; i < _beneficiaries.length; i++) {
            _pay(_beneficiaries[i], _balances[i]);
            total = total - _balances[i];
        }
        _checkTotal(total);
        emit MultiSendEth(_total);
    }

    // Owner only functions

    function claimTokens(address _token, uint256 _amount)
        external
        onlyOwner()
        nonReentrant()
    {
        address payable ownerPayable = payable(owner());
        uint256 amount = _amount == 0 ? address(this).balance : _amount;

        if (_token == address(0)) {
            _pay(ownerPayable, amount);
            emit ClaimedEther(ownerPayable, amount);
            return;
        }
        IERC20 erc20token = IERC20(_token);

        amount = _amount == 0 ? erc20token.balanceOf(address(this)) : _amount;

        require(
            erc20token.transfer(ownerPayable, amount),
            "FireAirdrop: Could not transfer the ERC 20 tokens."
        );
        emit ClaimedTokens(_token, ownerPayable, amount);
    }

    function setFee(uint128 _fee) external onlyOwner() {
        fee = _fee;
    }
}

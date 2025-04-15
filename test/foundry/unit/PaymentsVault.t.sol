// Copyright 2025 Nevermined AG.
// SPDX-License-Identifier: (Apache-2.0 AND CC-BY-4.0)
// Code is Apache-2.0 and docs are CC-BY-4.0
pragma solidity ^0.8.28;

import {PaymentsVault} from '../../../contracts/PaymentsVault.sol';
import {INVMConfig} from '../../../contracts/interfaces/INVMConfig.sol';
import {IVault} from '../../../contracts/interfaces/IVault.sol';
import {MockERC20} from '../../../contracts/test/MockERC20.sol';

import {PaymentsVaultV2} from '../../../contracts/mock/PaymentsVaultV2.sol';
import {BaseTest} from '../common/BaseTest.sol';
import {UUPSUpgradeable} from '@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol';

contract PaymentsVaultTest is BaseTest {
    address public depositor;
    address public withdrawer;
    address public receiver;
    MockERC20 public mockERC20;
    // Using DEPOSITOR_ROLE and WITHDRAW_ROLE from BaseTest
    
    function setUp() public override {
        super.setUp();
        
        depositor = makeAddr('depositor');
        withdrawer = makeAddr('withdrawer');
        receiver = makeAddr('receiver');
        
        // Deploy MockERC20
        mockERC20 = new MockERC20("Mock Token", "MTK");
        
        // Grant roles
        vm.prank(owner);
        nvmConfig.grantRole(DEPOSITOR_ROLE, depositor);
        
        vm.prank(owner);
        nvmConfig.grantRole(WITHDRAW_ROLE, withdrawer);
        
        // Mint some tokens to depositor
        mockERC20.mint(depositor, 1000 * 10**18);
    }

    function test_depositNativeToken() public {
        uint256 depositAmount = 0.1 ether;
        
        vm.deal(depositor, depositAmount);
        
        vm.prank(depositor);
        vm.expectEmit(true, true, true, true);
        emit IVault.ReceivedNativeToken(depositor, depositAmount);
        paymentsVault.depositNativeToken{value: depositAmount}();
        
        assertEq(paymentsVault.getBalanceNativeToken(), depositAmount);
    }
    
    function test_depositNativeToken_onlyDepositor() public {
        uint256 depositAmount = 0.1 ether;
        
        vm.deal(withdrawer, depositAmount);
        
        vm.prank(withdrawer);
        vm.expectPartialRevert(INVMConfig.InvalidRole.selector);
        paymentsVault.depositNativeToken{value: depositAmount}();
    }
    
    function test_withdrawNativeToken() public {
        uint256 depositAmount = 0.1 ether;
        uint256 withdrawAmount = 0.05 ether;
        
        // First deposit
        vm.deal(depositor, depositAmount);
        vm.prank(depositor);
        paymentsVault.depositNativeToken{value: depositAmount}();
        
        // Get receiver balance before
        uint256 receiverBalanceBefore = address(receiver).balance;
        
        // Withdraw
        vm.prank(withdrawer);
        vm.expectEmit(true, true, true, true);
        emit IVault.WithdrawNativeToken(withdrawer, receiver, withdrawAmount);
        paymentsVault.withdrawNativeToken(withdrawAmount, receiver);
        
        // Verify vault balance
        assertEq(paymentsVault.getBalanceNativeToken(), depositAmount - withdrawAmount);
        
        // Verify receiver balance
        assertEq(address(receiver).balance - receiverBalanceBefore, withdrawAmount);
    }
    
    function test_withdrawNativeToken_onlyWithdrawer() public {
        uint256 depositAmount = 0.1 ether;
        uint256 withdrawAmount = 0.05 ether;
        
        // First deposit
        vm.deal(depositor, depositAmount);
        vm.prank(depositor);
        paymentsVault.depositNativeToken{value: depositAmount}();
        
        // Try to withdraw as non-withdrawer
        vm.prank(depositor);
        vm.expectPartialRevert(INVMConfig.InvalidRole.selector);
        paymentsVault.withdrawNativeToken(withdrawAmount, receiver);
    }
    
    function test_depositERC20() public {
        uint256 depositAmount = 100 * 10**18;
        
        // Approve tokens first
        vm.prank(depositor);
        mockERC20.approve(address(paymentsVault), depositAmount);
        
        // Deposit
        vm.prank(depositor);
        vm.expectEmit(true, true, true, true);
        emit IVault.ReceivedERC20(address(mockERC20), depositor, depositAmount);
        paymentsVault.depositERC20(address(mockERC20), depositAmount, depositor);
        
        // Verify balance
        assertEq(mockERC20.balanceOf(address(paymentsVault)), depositAmount);
    }
    
    function test_depositERC20_onlyDepositor() public {
        uint256 depositAmount = 100 * 10**18;
        
        vm.prank(withdrawer);
        vm.expectPartialRevert(INVMConfig.InvalidRole.selector);
        paymentsVault.depositERC20(address(mockERC20), depositAmount, withdrawer);
    }
    
    function test_getBalanceNativeToken() public {
        // Initial balance should be 0
        assertEq(paymentsVault.getBalanceNativeToken(), 0);
        
        // Deposit some tokens
        uint256 depositAmount = 0.1 ether;
        vm.deal(depositor, depositAmount);
        vm.prank(depositor);
        paymentsVault.depositNativeToken{value: depositAmount}();
        
        // Check balance again
        assertEq(paymentsVault.getBalanceNativeToken(), depositAmount);
    }
    
    function test_getBalanceERC20() public {
        // Initial balance should be 0
        assertEq(paymentsVault.getBalanceERC20(address(mockERC20)), 0);
        
        // Transfer some tokens to the vault
        uint256 transferAmount = 100 * 10**18;
        vm.prank(depositor);
        mockERC20.transfer(address(paymentsVault), transferAmount);
        
        // Check balance again
        assertEq(paymentsVault.getBalanceERC20(address(mockERC20)), transferAmount);
    }
    
    function test_receiveFunction_depositor() public {
        uint256 depositAmount = 0.1 ether;
        
        vm.deal(depositor, depositAmount);
        
        // Send ETH directly to the contract
        vm.prank(depositor);
        (bool success,) = address(paymentsVault).call{value: depositAmount}("");
        
        assertTrue(success);
        assertEq(paymentsVault.getBalanceNativeToken(), depositAmount);
    }
    
    function test_receiveFunction_nonDepositor() public {
        uint256 depositAmount = 0.1 ether;
        
        vm.deal(withdrawer, depositAmount);
        
        // Try to send ETH directly to the contract
        vm.prank(withdrawer);
        (bool success,) = address(paymentsVault).call{value: depositAmount}("");
        
        assertFalse(success);
    }

    function test_upgraderShouldBeAbleToUpgradeAfterDelay() public {
        string memory newVersion = '2.0.0';

        uint48 upgradeTime = uint48(block.timestamp + UPGRADE_DELAY);

        PaymentsVaultV2 paymentsVaultV2Impl = new PaymentsVaultV2();

        vm.prank(upgrader);
        accessManager.schedule(
            address(paymentsVault),
            abi.encodeCall(UUPSUpgradeable.upgradeToAndCall, (address(paymentsVaultV2Impl), bytes(''))),
            upgradeTime
        );

        vm.warp(upgradeTime);

        vm.prank(upgrader);
        accessManager.execute(
            address(paymentsVault),
            abi.encodeCall(UUPSUpgradeable.upgradeToAndCall, (address(paymentsVaultV2Impl), bytes('')))
        );

        PaymentsVaultV2 paymentsVaultV2 = PaymentsVaultV2(payable(address(paymentsVault)));

        vm.prank(governor);
        paymentsVaultV2.initializeV2(newVersion);

        assertEq(paymentsVaultV2.getVersion(), newVersion);
    }
}

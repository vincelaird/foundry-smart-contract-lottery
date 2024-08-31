// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";

/**
 * @title HelperConfigTest
 * @author Vince Laird
 * @notice This contract contains unit tests for the HelperConfig contract
 * @dev Uses Foundry's test framework
 */
contract HelperConfigTest is Test {
    HelperConfig public helperConfig;

    /**
     * @notice Set up the test environment before each test
     * @dev Deploys a new HelperConfig contract
     */
    function setUp() public {
        helperConfig = new HelperConfig();
    }

    /**
     * @notice Test getting configuration for different chain IDs
     * @dev Tests configurations for Sepolia and Anvil, and checks for revert on invalid chain ID
     */
    function testGetConfigByChainId() public {
        // Test configuration for Sepolia testnet
        _testConfig(11155111, "Sepolia");

        // Test configuration for local Anvil network
        _testConfig(31337, "Anvil");

        // Test for invalid chain ID (Ethereum mainnet, which is not supported)
        vm.expectRevert(HelperConfig.HelperConfig__InvalidChainid.selector);
        helperConfig.getConfigByChainId(1);
    }

    /**
     * @notice Helper function to test configuration for a specific chain
     * @param chainId The chain ID to test
     * @param networkName The name of the network (for assertion messages)
     */
    function _testConfig(uint256 chainId, string memory networkName) internal {
        HelperConfig.NetworkConfig memory config = helperConfig
            .getConfigByChainId(chainId);

        // Check if VRF Coordinator is set
        assertTrue(
            config.vrfCoordinator != address(0),
            string.concat("VRF Coordinator should be set for ", networkName)
        );

        // Check if entrance fee is set
        assertTrue(
            config.entranceFee > 0,
            string.concat("Entrance fee should be set for ", networkName)
        );

        // Check if interval is set
        assertTrue(
            config.interval > 0,
            string.concat("Interval should be set for ", networkName)
        );
    }
}

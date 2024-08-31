// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {Script, console2} from "forge-std/Script.sol";
import {HelperConfig, CodeConstants} from "script/HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts@1.2.0/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "test/mocks/LinkToken.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract CreateSubscription is Script {
    event SubscriptionCreated(uint256 subId);

    function createSubscriptionUsingConfig(
        HelperConfig helperConfig
    ) public returns (uint256, address) {
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        address vrfCoordinator = config.vrfCoordinator;
        address account = config.account;
        (uint256 subId, ) = createSubscription(vrfCoordinator, account);
        return (subId, vrfCoordinator);
    }

    function createSubscription(
        address vrfCoordinator,
        address account
    ) public returns (uint256, address) {
        console2.log("Creating subscription on chain id:", block.chainid);
        vm.startBroadcast(account);
        uint256 subId = VRFCoordinatorV2_5Mock(vrfCoordinator)
            .createSubscription();
        vm.stopBroadcast();

        console2.log("Subscription ID:", subId);
        return (subId, vrfCoordinator);
    }

    function run(address account) public {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        config.account = account; // Override the account with the provided one
        (uint256 subId, address vrfCoordinator) = createSubscriptionUsingConfig(
            helperConfig
        );
        console2.log("Subscription ID:", subId);
        console2.log("VRF Coordinator:", vrfCoordinator);
        emit SubscriptionCreated(subId);
    }
}

contract FundSubscription is CodeConstants, Script {
    uint256 public constant FUND_AMOUNT = 300 ether; // 300 LINK

    function fundSubscriptionUsingConfig(HelperConfig helperConfig) public {
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        fundSubscription(
            config.vrfCoordinator,
            config.subscriptionId,
            config.link,
            config.account
        );
    }

    function fundSubscription(
        address vrfCoordinator,
        uint256 subscriptionId,
        address linkToken,
        address account
    ) public {
        console2.log("Funding subscription:", subscriptionId);
        console2.log("Chainlink VRF Coordinator:", vrfCoordinator);
        console2.log("On chain:", block.chainid);
        console2.log("Account:", account);
        console2.log("LINK token address:", linkToken);

        require(subscriptionId != 0, "Subscription ID cannot be 0");

        VRFCoordinatorV2_5Mock(vrfCoordinator).fundSubscription(
            subscriptionId,
            FUND_AMOUNT
        );

        console2.log("Subscription funded with amount:", FUND_AMOUNT);
    }

    function run() public {
        HelperConfig helperConfig = new HelperConfig();
        fundSubscriptionUsingConfig(helperConfig);
    }
}

contract AddConsumer is Script {
    function addConsumerUsingConfig(
        address consumerAddress,
        address account,
        HelperConfig helperConfig
    ) public {
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        addConsumer(
            consumerAddress,
            config.vrfCoordinator,
            config.subscriptionId,
            account
        );
    }

    function addConsumer(
        address contractToAddToVrf,
        address vrfCoordinator,
        uint256 subscriptionId,
        address account
    ) public {
        console2.log("Adding consumer:", contractToAddToVrf);
        console2.log("Adding to VRF Coordinator:", vrfCoordinator);
        console2.log("Using Subscription ID:", subscriptionId);
        console2.log("On chain:", block.chainid);
        vm.prank(account);
        VRFCoordinatorV2_5Mock(vrfCoordinator).addConsumer(
            subscriptionId,
            contractToAddToVrf
        );
    }

    function run(address overrideAddress, address account) public {
        HelperConfig helperConfig = new HelperConfig();
        address mostRecentlyDeployed = overrideAddress == address(0)
            ? DevOpsTools.get_most_recent_deployment("Raffle", block.chainid)
            : overrideAddress;
        vm.startBroadcast(account);
        addConsumerUsingConfig(mostRecentlyDeployed, account, helperConfig);
        vm.stopBroadcast();
    }
}

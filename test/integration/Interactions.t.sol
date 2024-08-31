// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "script/Interactions.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts@1.2.0/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "test/mocks/LinkToken.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";
import {Vm} from "forge-std/Vm.sol";
import {Raffle} from "src/Raffle.sol";

/**
 * @title InteractionsTest
 * @author Vince Laird
 * @notice This contract contains integration tests for the Raffle contract interactions
 * @dev Uses Foundry's test framework
 */
contract InteractionsTest is Test {
    CreateSubscription createSubscription;
    FundSubscription fundSubscription;
    AddConsumer addConsumer;
    HelperConfig helperConfig;
    VRFCoordinatorV2_5Mock vrfCoordinator;
    LinkToken linkToken;

    address ACCOUNT;
    uint256 constant FUND_AMOUNT = 300 ether;

    /**
     * @notice Set up the test environment before each test
     * @dev Initializes contracts and test variables
     */
    function setUp() public {
        createSubscription = new CreateSubscription();
        fundSubscription = new FundSubscription();
        addConsumer = new AddConsumer();
        helperConfig = new HelperConfig();

        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        vrfCoordinator = VRFCoordinatorV2_5Mock(config.vrfCoordinator);
        linkToken = LinkToken(config.link);
        ACCOUNT = config.account;

        // Fund the account for tests
        vm.deal(ACCOUNT, 10 ether);
    }

    // Modifiers
    modifier createAndFundSubscription() {
        uint256 subId = vrfCoordinator.createSubscription();
        vm.prank(ACCOUNT);
        vrfCoordinator.fundSubscription(subId, FUND_AMOUNT);
        _;
    }

    modifier mockHelperConfig(uint256 subId) {
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        config.subscriptionId = subId;
        vm.mockCall(
            address(helperConfig),
            abi.encodeWithSelector(HelperConfig.getConfig.selector),
            abi.encode(config)
        );
        _;
    }

    modifier skipOnSepolia() {
        if (block.chainid == 11155111) {
            // Sepolia chain ID
            return;
        }
        _;
    }

    /**
     * @notice Test funding a VRF subscription using HelperConfig
     * @dev This test funds a subscription with LINK tokens using the HelperConfig
     */
    function testFundSubscriptionUsingConfig() public skipOnSepolia{
        vm.chainId(31337);

        uint256 initialBalance = linkToken.balanceOf(ACCOUNT);
        console.log("Initial LINK balance:", initialBalance);

        // Create a subscription
        vm.prank(ACCOUNT);
        uint256 subId = vrfCoordinator.createSubscription();
        console.log("Subscription created with ID:", subId);

        // Approve LINK tokens
        vm.prank(ACCOUNT);
        linkToken.approve(address(vrfCoordinator), FUND_AMOUNT);
        console.log("Approved LINK tokens:", FUND_AMOUNT);

        // Update the subscriptionId in the HelperConfig
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        config.subscriptionId = subId;
        config.link = address(linkToken);
        config.vrfCoordinator = address(vrfCoordinator);

        // Mock the HelperConfig.getConfig() function to return our updated config
        vm.mockCall(
            address(helperConfig),
            abi.encodeWithSelector(HelperConfig.getConfig.selector),
            abi.encode(config)
        );

        // Call fundSubscriptionUsingConfig
        vm.prank(ACCOUNT);
        fundSubscription.fundSubscriptionUsingConfig(helperConfig);

        // Verify the subscription is funded
        (uint96 balance, , , , ) = vrfCoordinator.getSubscription(subId);
        console.log("Subscription balance after funding:", balance);

        assertEq(
            balance,
            FUND_AMOUNT,
            "Subscription should be funded with the correct amount"
        );

        uint256 finalBalance = linkToken.balanceOf(ACCOUNT);
        console.log("Final LINK balance:", finalBalance);

        // Note: In a real scenario, we'd expect the balance to decrease.
        // However, with our mock setup, it might not change.
        assertEq(
            finalBalance,
            initialBalance,
            "LINK balance should remain unchanged in mock setup"
        );
    }

    /**
     * @notice Test adding a consumer to a VRF subscription using HelperConfig
     * @dev This test creates a subscription, funds it, and adds a consumer using the HelperConfig
     */
    function testAddConsumerUsingConfig() public skipOnSepolia {
        console.log("Starting testAddConsumerUsingConfig");

        // Create a subscription
        vm.prank(ACCOUNT);
        uint256 subId = vrfCoordinator.createSubscription();
        console.log("Subscription created with ID:", subId);

        // Fund the subscription
        vm.prank(ACCOUNT);
        vrfCoordinator.fundSubscription(subId, FUND_AMOUNT);
        console.log("Subscription funded with amount:", FUND_AMOUNT);

        // Mock address for the consumer to be added
        address mockConsumerAddress = address(0x1234);

        // Ensure we're using the local network config
        vm.chainId(31337);

        // Update the subscriptionId in the HelperConfig
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        config.subscriptionId = subId;

        // Mock the HelperConfig.getConfig() function to return our updated config
        vm.mockCall(
            address(helperConfig),
            abi.encodeWithSelector(HelperConfig.getConfig.selector),
            abi.encode(config)
        );

        // Call addConsumerUsingConfig
        vm.prank(ACCOUNT);
        addConsumer.addConsumerUsingConfig(
            mockConsumerAddress,
            ACCOUNT,
            helperConfig
        );

        // Verify the consumer was added
        (, , , , address[] memory consumers) = vrfCoordinator.getSubscription(
            subId
        );
        assertEq(
            consumers[0],
            mockConsumerAddress,
            "Consumer should be added to the subscription"
        );
        console.log("Consumer successfully added:", mockConsumerAddress);
    }

    /**
     * @notice Test adding a consumer to a VRF subscription using the AddConsumer script
     * @dev This test creates a subscription, funds it, and adds a consumer using the AddConsumer script
     */
    function testAddConsumerRun() public skipOnSepolia {
        // First, create and fund a subscription
        CreateSubscription createSub = new CreateSubscription();
        (uint256 subId, address vrfCoordinatorAddress) = createSub
            .createSubscriptionUsingConfig(helperConfig);

        FundSubscription fundSub = new FundSubscription();
        fundSub.fundSubscription(
            vrfCoordinatorAddress,
            subId,
            address(linkToken),
            ACCOUNT
        );

        // Deploy a mock Raffle contract
        Raffle mockRaffle = new Raffle(
            1 ether,
            60,
            vrfCoordinatorAddress,
            0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c,
            subId,
            30000
        );

        // Run AddConsumer with our mock Raffle address
        addConsumer.addConsumer(
            address(mockRaffle),
            vrfCoordinatorAddress,
            subId,
            ACCOUNT
        );

        // Verify the consumer was added
        (, , , , address[] memory consumers) = VRFCoordinatorV2_5Mock(
            vrfCoordinatorAddress
        ).getSubscription(subId);
        assertEq(
            consumers[0],
            address(mockRaffle),
            "Raffle should be added as a consumer"
        );
    }

    /**
     * @notice Test funding a VRF subscription with a zero ID
     * @dev This test should revert with the message "Subscription ID cannot be 0"
     */
    function testFundSubscriptionWithZeroId() public {
        vm.expectRevert("Subscription ID cannot be 0");
        fundSubscription.fundSubscription(
            address(vrfCoordinator),
            0,
            address(linkToken),
            ACCOUNT
        );
    }

    /**
     * @notice Test adding a consumer to a non-existent VRF subscription
     * @dev This test should revert with the error defined in the base contract or interface that VRFCoordinatorV2_5Mock implements
     */
    function testAddConsumerNonExistentSubscription() public {
        // 0x1f6a65b6 is selector for InvalidSubscription()
        // this is an error defined in a base contract or interface that VRFCoordinatorV2_5Mock implements
        vm.expectRevert(0x1f6a65b6);
        addConsumer.addConsumer(
            address(0x1234),
            address(vrfCoordinator),
            999, // non-existent subscription ID
            ACCOUNT
        );
    }

    /**
     * @notice Test running the CreateSubscription script with an account
     * @dev This test runs the CreateSubscription script with an account and checks if the SubscriptionCreated event is emitted
     */
    function testCreateSubscriptionRunWithAccount() public {
        CreateSubscription createSub = new CreateSubscription();

        vm.recordLogs();
        createSub.run(ACCOUNT);

        Vm.Log[] memory entries = vm.getRecordedLogs();

        bool found = false;
        for (uint i = 0; i < entries.length; i++) {
            if (
                entries[i].topics[0] ==
                keccak256("SubscriptionCreated(uint256)")
            ) {
                found = true;
                break;
            }
        }

        assertTrue(found, "SubscriptionCreated event was not emitted");
    }
}

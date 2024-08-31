// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {HelperConfig, CodeConstants} from "script/HelperConfig.s.sol";
import {Raffle} from "src/Raffle.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts@1.2.0/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";

/**
 * @title RaffleTest
 * @author Vince Laird
 * @notice This contract contains unit tests for the Raffle contract
 * @dev Uses Foundry's test framework
 */
contract RaffleTest is Test, CodeConstants {
    Raffle public raffle;
    HelperConfig public helperConfig;

    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint32 callbackGasLimit;
    uint256 subscriptionId;
    address link;

    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_PLAYER_BALANCE = 10 ether;

    /**
     * Events (copied from contract)
     */
    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner);

    /**
     * @notice Set up the test environment before each test
     * @dev Deploys a new Raffle contract and sets up test variables
     * @dev Only runs on local chains to avoid interacting with live networks during testing
     * @dev Tests on non-local chains are skipped to prevent unintended side effects or costs
     */
    function setUp() external {
        if (block.chainid == LOCAL_CHAIN_ID) {
            DeployRaffle deployer = new DeployRaffle();
            (raffle, helperConfig) = deployer.deployContract();

            HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
            entranceFee = config.entranceFee;
            interval = config.interval;
            vrfCoordinator = config.vrfCoordinator;
            gasLane = config.gasLane;
            callbackGasLimit = config.callbackGasLimit;
            subscriptionId = config.subscriptionId;
            link = config.link;

            vm.deal(PLAYER, STARTING_PLAYER_BALANCE);
        }
    }

    modifier raffleEntered() {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    modifier skipFork() {
        if (block.chainid != LOCAL_CHAIN_ID) {
            vm.skip(true);
        }
        _;
    }

    /**
     * @notice Test if the Raffle initializes in the OPEN state
     */
    function testRaffleInitializesInOpenState() public skipFork {
        // Check if the initial state of the Raffle is OPEN
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    /**
     * Enter Raffle
     */

    /**
     * @notice Test if the Raffle reverts when not enough ETH is sent
     */
    function testRaffleRevertsWhenNotEnoughEthSent() public skipFork {
        // Arrange: Set up the test player
        vm.prank(PLAYER);

        // Act & Assert: Try to enter the raffle without sending enough ETH, expect it to revert
        vm.expectRevert(Raffle.Raffle__NotEnoughEthSentToEnterRaffle.selector);
        raffle.enterRaffle();
    }

    /**
     * @notice Test if the Raffle records players when they enter
     */
    function testRaffleRecordsPlayersWhenTheyEnter() public skipFork {
        // Arrange: Set up the test player
        vm.prank(PLAYER);

        // Act: Enter the raffle
        raffle.enterRaffle{value: entranceFee}();

        // Assert: Check if the player is recorded
        address playerRecorded = raffle.getPlayer(0);
        assert(playerRecorded == PLAYER);
    }

    /**
     * @notice Test if the Raffle emits an event when a player enters
     */
    function testRaffleEmitsEventWhenPlayerEnters() public skipFork {
        // Arrange: Set up the test player
        vm.prank(PLAYER);

        // Act: Enter the raffle and expect the RaffleEntered event
        vm.expectEmit(true, false, false, false, address(raffle));
        emit RaffleEntered(PLAYER);

        // Assert: Check if the event was emitted
        raffle.enterRaffle{value: entranceFee}();
    }

    /**
     * @notice Test if the Raffle does not allow players to enter when it is not open
     */
    function testDoNotAllowPlayersToEnterWhenRaffleIsNotOpen()
        public
        skipFork
        raffleEntered
    {
        // Arrange: Set up the test player, enter the raffle, and close it
        // (modifier used)
        raffle.performUpkeep("");

        // Act & Assert: Try to enter the raffle again, expect it to revert
        vm.expectRevert(Raffle.Raffle__NotOpen.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }

    /**
     * Check Upkeep
     */

    /**
     * @notice Test if checkUpkeep returns false if the Raffle has no balance
     */
    function testCheckUpkeepReturnsFalseIfItHasNoBalance() public skipFork {
        // Arrange: Advance the block timestamp and number
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        // Act: Check upkeep
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        // Assert: Check if upkeep is not needed
        assert(!upkeepNeeded);
    }

    /**
     * @notice Test if checkUpkeep returns false if the Raffle is not open
     */
    function testCheckUpkeepReturnsFalseIfRaffleIsNotOpen()
        public
        skipFork
        raffleEntered
    {
        // Arrange: Set up the test player, enter the raffle, and close it
        // (modifier used)
        raffle.performUpkeep("");

        // Act: Check upkeep
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        // Assert: Check if upkeep is not needed
        assert(!upkeepNeeded);
    }

    /**
     * @notice Test if checkUpkeep returns false if enough time has not passed
     */
    function testCheckUpkeepReturnsFalseIfEnoughTimeHasntPassed()
        public
        skipFork
    {
        // Arrange: Set up the test player and enter the raffle
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();

        // Act: Check upkeep
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        // Assert: Check if upkeep is not needed
        assert(!upkeepNeeded);
    }

    /**
     * @notice Test if checkUpkeep returns true when the parameters are good
     */
    function testCheckUpkeepReturnsTrueWhenParametersGood()
        public
        skipFork
        raffleEntered
    {
        // Arrange: Set up the test player, enter the raffle, and advance the block timestamp and number
        // (modifier used)

        // Act: Check upkeep
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        // Assert: Check if upkeep is needed
        assert(upkeepNeeded);
    }

    /**
     * Perform Upkeep
     */

    /**
     * @notice Test if performUpkeep can only run if checkUpkeep is true
     */
    function testPerformUpkeepCanOnlyRunIfCheckUpkeepIsTrue()
        public
        skipFork
        raffleEntered
    {
        // Arrange: Set up the test player, enter the raffle, and advance the block timestamp and number
        // (modifier used)

        // Act: Perform upkeep
        raffle.performUpkeep("");
    }

    /**
     * @notice Test if performUpkeep reverts if checkUpkeep is false
     */
    function testPerformUpkeepRevertsIfCheckUpkeepIsFalse() public skipFork {
        // Arrange: Set up the test player, enter the raffle, and get the current balance and number of players
        uint256 currentBalance = 0;
        uint256 numPlayers = 0;
        Raffle.RaffleState raffleState = raffle.getRaffleState();

        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        currentBalance = currentBalance + entranceFee;
        numPlayers = numPlayers + 1;

        // Act & Assert: Try to perform upkeep, expect it to revert
        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.Raffle__UpkeepNotNeeded.selector,
                currentBalance,
                numPlayers,
                raffleState
            )
        );
        raffle.performUpkeep("");
    }

    /**
     * @notice Test if performUpkeep updates the Raffle state and emits a requestId
     */
    function testPerformUpkeepUpdatesRaffleStateAndEmitsRequestId()
        public
        skipFork
        raffleEntered
    {
        // Act: Perform upkeep and record the logs
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        // Assert: Check if the requestId is emitted and the Raffle state is updated
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        assert(uint256(requestId) > 0);
        assert(raffleState == Raffle.RaffleState.CALCULATING);
    }

    /**
     * Fulfill Random Words
     */

    /**
     * @notice Test if fulfillRandomWords can only be called after performUpkeep
     * @dev This test is skipped on non-local chains
     */
    function testFulfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep(
        uint256 randomRequestId
    ) public skipFork raffleEntered {
        // Arrange / Act / Assert: Try to fulfill random words without performing upkeep, expect it to revert
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(
            randomRequestId,
            address(raffle)
        );
    }

    /**
     * @notice Test if fulfillRandomWords picks a winner, resets the raffle, and sends the prize
     * @dev This test is skipped on non-local chains
     */
    function testFulfillRandomWordsPicksAWinnerResetsAndSendsMoney()
        public
        skipFork
        raffleEntered
    {
        // Arrange: Set up multiple players to enter the raffle
        uint256 additionalEntrants = 3; // 4 total
        uint256 startingIndex = 1;
        address expectedWinner = address(1);

        for (
            uint256 i = startingIndex;
            i < startingIndex + additionalEntrants;
            i++
        ) {
            address newPlayer = address(uint160(i));
            hoax(newPlayer, 1 ether);
            raffle.enterRaffle{value: entranceFee}();
        }
        uint256 startingTimestamp = raffle.getLastTimestamp();
        uint256 winnerStartingBalance = expectedWinner.balance;

        // Act: Perform upkeep and fulfill random words to pick a winner
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(
            uint256(requestId),
            address(raffle)
        );

        // Assert: Check if the winner is correctly picked and prize is distributed
        address recentWinner = raffle.getRecentWinner();
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        uint256 winnerBalance = recentWinner.balance;
        uint256 endingTimestamp = raffle.getLastTimestamp();
        uint256 prize = entranceFee * (additionalEntrants + 1);

        assert(recentWinner == expectedWinner);
        assert(raffleState == Raffle.RaffleState.OPEN);
        assert(winnerBalance == winnerStartingBalance + prize);
        assert(endingTimestamp > startingTimestamp);
    }
}

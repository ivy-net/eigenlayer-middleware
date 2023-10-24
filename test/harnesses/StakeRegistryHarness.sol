// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.12;

import "src/StakeRegistry.sol";

// wrapper around the StakeRegistry contract that exposes the internal functions for unit testing.
contract StakeRegistryHarness is StakeRegistry {
    mapping(uint8 => mapping(address => uint96)) private _weightOfOperatorForQuorum;

    constructor(
        IRegistryCoordinator _registryCoordinator,
        IStrategyManager _strategyManager,
        IServiceManager _serviceManager
    ) StakeRegistry(_registryCoordinator, _strategyManager, _serviceManager) {
    }

    function recordOperatorStakeUpdate(bytes32 operatorId, uint8 quorumNumber, uint96 newStake) external returns(int256) {
        return _recordOperatorStakeUpdate(operatorId, quorumNumber, newStake);
    }

    function updateOperatorStake(address operator, bytes32 operatorId, uint8 quorumNumber) external returns (int256, uint96) {
        return _updateOperatorStake(operator, operatorId, quorumNumber);
    }

    function recordTotalStakeUpdate(uint8 quorumNumber, int256 stakeDelta) external {
        _recordTotalStakeUpdate(quorumNumber, stakeDelta);
    }

    // mocked function so we can set this arbitrarily without having to mock other elements
    function weightOfOperatorForQuorum(uint8 quorumNumber, address operator) public override view returns(uint96) {
        return _weightOfOperatorForQuorum[quorumNumber][operator];
    }

    /// TODO remove when core gets updated
    function weightOfOperatorForQuorumView(uint8 quorumNumber, address operator) public override view returns(uint96) {
        return _weightOfOperatorForQuorum[quorumNumber][operator];
    }

    // mocked function so we can set this arbitrarily without having to mock other elements
    function setOperatorWeight(uint8 quorumNumber, address operator, uint96 weight) external {
        _weightOfOperatorForQuorum[quorumNumber][operator] = weight;
    }

    // mocked function to register an operator without having to mock other elements
    // This is just a copy/paste from `registerOperator`, since that no longer uses an internal method
    function registerOperatorNonCoordinator(address operator, bytes32 operatorId, bytes calldata quorumNumbers) external {
        // check the operator is registering for only valid quorums
        require(
            uint8(quorumNumbers[quorumNumbers.length - 1]) < quorumCount,
            "StakeRegistry._registerOperator: greatest quorumNumber must be less than quorumCount"
        );

        for (uint i = 0; i < quorumNumbers.length; ) {            
            /**
             * Update the operator's stake for the quorum and retrieve their current stake
             * as well as the change in stake.
             * If this method returns `stake == 0`, the operator has not met the minimum requirement
             * 
             * TODO - we only use the `stake` return here. It's probably better to use a bool instead
             *        of relying on the method returning "0" in only this one case.
             */
            uint8 quorumNumber = uint8(quorumNumbers[i]);
            (int256 stakeDelta, uint96 stake) = _updateOperatorStake({
                operator: operator, 
                operatorId: operatorId, 
                quorumNumber: quorumNumber
            });
            require(
                stake != 0,
                "StakeRegistry._registerOperator: Operator does not meet minimum stake requirement for quorum"
            );

            // Update this quorum's total stake
            _recordTotalStakeUpdate(quorumNumber, stakeDelta);
            unchecked {
                ++i;
            }
        }
    }
}

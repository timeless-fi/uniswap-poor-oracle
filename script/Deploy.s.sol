// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.13;

import {CREATE3Script} from "./base/CREATE3Script.sol";
import {UniswapPoorOracle} from "../src/UniswapPoorOracle.sol";

contract DeployScript is CREATE3Script {
    constructor() CREATE3Script(vm.envString("VERSION")) {}

    function run() external returns (UniswapPoorOracle oracle) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

        uint256 inRangeThreshold = vm.envUint("IN_RANGE_THRESHOLD");
        require(inRangeThreshold > 0 && inRangeThreshold < 1e18, "Invalid IN_RANGE_THRESHOLD value");
        uint256 recordingMinLength = vm.envUint("RECORDING_MIN_LENGTH");
        require(recordingMinLength >= 30 minutes, "Invalid RECORDING_MIN_LENGTH value");
        uint256 recordingMaxLength = vm.envUint("RECORDING_MAX_LENGTH");
        require(recordingMinLength <= 1 days, "Invalid RECORDING_MAX_LENGTH value");

        vm.startBroadcast(deployerPrivateKey);

        oracle = UniswapPoorOracle(
            create3.deploy(
                getCreate3ContractSalt("UniswapPoorOracle"),
                bytes.concat(
                    type(UniswapPoorOracle).creationCode,
                    abi.encode(inRangeThreshold, recordingMinLength, recordingMaxLength)
                )
            )
        );

        vm.stopBroadcast();
    }
}

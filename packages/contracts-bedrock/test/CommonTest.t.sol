// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

// Testing utilities
import { Test, StdUtils } from "forge-std/Test.sol";
import { Vm } from "forge-std/Vm.sol";
import { L2OutputOracle } from "src/L1/L2OutputOracle.sol";
import { L2ToL1MessagePasser } from "src/L2/L2ToL1MessagePasser.sol";
import { L1StandardBridge } from "src/L1/L1StandardBridge.sol";
import { L2StandardBridge } from "src/L2/L2StandardBridge.sol";
import { StandardBridge } from "src/universal/StandardBridge.sol";
import { L1ERC721Bridge } from "src/L1/L1ERC721Bridge.sol";
import { L2ERC721Bridge } from "src/L2/L2ERC721Bridge.sol";
import { OptimismMintableERC20Factory } from "src/universal/OptimismMintableERC20Factory.sol";
import { OptimismMintableERC721Factory } from "src/universal/OptimismMintableERC721Factory.sol";
import { OptimismMintableERC20 } from "src/universal/OptimismMintableERC20.sol";
import { OptimismPortal } from "src/L1/OptimismPortal.sol";
import { L1CrossDomainMessenger } from "src/L1/L1CrossDomainMessenger.sol";
import { L2CrossDomainMessenger } from "src/L2/L2CrossDomainMessenger.sol";
import { SequencerFeeVault } from "src/L2/SequencerFeeVault.sol";
import { L1FeeVault } from "src/L2/L1FeeVault.sol";
import { BaseFeeVault } from "src/L2/BaseFeeVault.sol";
import { FeeVault } from "src/universal/FeeVault.sol";
import { GasPriceOracle } from "src/L2/GasPriceOracle.sol";
import { L1Block } from "src/L2/L1Block.sol";
import { ProtocolVersions } from "src/L1/ProtocolVersions.sol";
import { FeeVault } from "src/universal/FeeVault.sol";
import { AddressAliasHelper } from "src/vendor/AddressAliasHelper.sol";
import { LegacyERC20ETH } from "src/legacy/LegacyERC20ETH.sol";
import { Predeploys } from "src/libraries/Predeploys.sol";
import { Types } from "src/libraries/Types.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Proxy } from "src/universal/Proxy.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { ResolvedDelegateProxy } from "src/legacy/ResolvedDelegateProxy.sol";
import { AddressManager } from "src/legacy/AddressManager.sol";
import { L1ChugSplashProxy } from "src/legacy/L1ChugSplashProxy.sol";
import { IL1ChugSplashDeployer } from "src/legacy/L1ChugSplashProxy.sol";
import { CrossDomainMessenger } from "src/universal/CrossDomainMessenger.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { LegacyMintableERC20 } from "src/legacy/LegacyMintableERC20.sol";
import { SystemConfig } from "src/L1/SystemConfig.sol";
import { ResourceMetering } from "src/L1/ResourceMetering.sol";
import { Constants } from "src/libraries/Constants.sol";
import { Deploy } from "scripts/Deploy.s.sol";

contract CommonTest is Deploy, Test {
    address alice = address(128);
    address bob = address(256);

    bytes32 constant nonZeroHash = keccak256(abi.encode("NON_ZERO"));

    event TransactionDeposited(address indexed from, address indexed to, uint256 indexed version, bytes opaqueData);

    /// @dev OpenZeppelin Ownable.sol transferOwnership event
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    OptimismPortal optimismPortal;
    L2OutputOracle l2OutputOracle;
    SystemConfig systemConfig;
    L1StandardBridge l1StandardBridge;
    L1CrossDomainMessenger l1CrossDomainMessenger;
    AddressManager addressManager;
    L1ERC721Bridge l1ERC721Bridge;
    OptimismMintableERC20Factory l1OptimismMintableERC20Factory;
    ProtocolVersions protocolVersions;

    L2CrossDomainMessenger l2CrossDomainMessenger;
    L2StandardBridge l2StandardBridge;
    L2ToL1MessagePasser l2ToL1MessagePasser;
    OptimismMintableERC20Factory l2OptimismMintableERC20Factory;
    L2ERC721Bridge l2ERC721Bridge;
    BaseFeeVault baseFeeVault;
    SequencerFeeVault sequencerFeeVault;
    L1FeeVault l1FeeVault;
    GasPriceOracle gasPriceOracle;
    L1Block l1Block;

    FFIInterface ffi;

    function setUp() public virtual override {
        // Give alice and bob some ETH
        vm.deal(alice, 1 << 16);
        vm.deal(bob, 1 << 16);

        vm.label(alice, "alice");
        vm.label(bob, "bob");

        // Make sure we have a non-zero base fee
        vm.fee(1000000000);

        // Set the deterministic deployer in state
        vm.etch(
            0x4e59b44847b379578588920cA78FbF26c0B4956C,
            hex"7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe03601600081602082378035828234f58015156039578182fd5b8082525050506014600cf3"
        );

        ffi = new FFIInterface();

        Deploy.setUp();
        Deploy.run();

        // Set up L1
        optimismPortal = OptimismPortal(mustGetAddress("OptimismPortalProxy"));
        l2OutputOracle = L2OutputOracle(mustGetAddress("L2OutputOracleProxy"));
        systemConfig = SystemConfig(mustGetAddress("SystemConfigProxy"));
        l1StandardBridge = L1StandardBridge(mustGetAddress("L1StandardBridgeProxy"));
        l1CrossDomainMessenger = L1CrossDomainMessenger(mustGetAddress("L1CrossDomainMessengerProxy"));
        addressManager = AddressManager(mustGetAddress("AddressManager"));
        l1ERC721Bridge = L1ERC721Bridge(mustGetAddress("L1ERC721BridgeProxy"));
        l1OptimismMintableERC20Factory =
            OptimismMintableERC20Factory(mustGetAddress("OptimismMintableERC20FactoryProxy"));
        protocolVersions = ProtocolVersions(mustGetAddress("ProtocolVersionsProxy"));

        vm.label(address(l2OutputOracle), "L2OutputOracle");
        vm.label(address(optimismPortal), "OptimismPortal");
        vm.label(address(systemConfig), "SystemConfig");
        vm.label(address(l1StandardBridge), "L1StandardBridge");
        vm.label(address(l1CrossDomainMessenger), "L1CrossDomainMessenger");
        vm.label(address(addressManager), "AddressManager");
        vm.label(address(l1ERC721Bridge), "L1ERC721Bridge");
        vm.label(address(l1OptimismMintableERC20Factory), "OptimismMintableERC20Factory");
        vm.label(address(protocolVersions), "ProtocolVersions");

        // Set up L2. There are currently no proxies set in the L2 initialization.
        vm.etch(
            Predeploys.L2_CROSS_DOMAIN_MESSENGER,
            address(new L2CrossDomainMessenger(address(l1CrossDomainMessenger))).code
        );
        l2CrossDomainMessenger = L2CrossDomainMessenger(payable(Predeploys.L2_CROSS_DOMAIN_MESSENGER));
        l2CrossDomainMessenger.initialize();

        vm.etch(Predeploys.L2_TO_L1_MESSAGE_PASSER, address(new L2ToL1MessagePasser()).code);
        l2ToL1MessagePasser = L2ToL1MessagePasser(payable(Predeploys.L2_TO_L1_MESSAGE_PASSER));

        vm.etch(
            Predeploys.L2_STANDARD_BRIDGE, address(new L2StandardBridge(StandardBridge(payable(l1StandardBridge)))).code
        );
        l2StandardBridge = L2StandardBridge(payable(Predeploys.L2_STANDARD_BRIDGE));
        l2StandardBridge.initialize();

        vm.etch(Predeploys.OPTIMISM_MINTABLE_ERC20_FACTORY, address(new OptimismMintableERC20Factory()).code);
        l2OptimismMintableERC20Factory = OptimismMintableERC20Factory(Predeploys.OPTIMISM_MINTABLE_ERC20_FACTORY);
        l2OptimismMintableERC20Factory.initialize(Predeploys.L2_STANDARD_BRIDGE);

        vm.etch(Predeploys.LEGACY_ERC20_ETH, address(new LegacyERC20ETH()).code);

        vm.etch(Predeploys.L2_ERC721_BRIDGE, address(new L2ERC721Bridge(address(l1ERC721Bridge))).code);
        l2ERC721Bridge = L2ERC721Bridge(Predeploys.L2_ERC721_BRIDGE);
        l2ERC721Bridge.initialize();

        vm.etch(
            Predeploys.SEQUENCER_FEE_WALLET,
            address(
                new SequencerFeeVault(cfg.sequencerFeeVaultRecipient(), cfg.sequencerFeeVaultMinimumWithdrawalAmount(), FeeVault.WithdrawalNetwork.L2)
            ).code
        );
        vm.etch(
            Predeploys.BASE_FEE_VAULT,
            address(
                new BaseFeeVault(cfg.baseFeeVaultRecipient(), cfg.baseFeeVaultMinimumWithdrawalAmount(), FeeVault.WithdrawalNetwork.L1)
            ).code
        );
        vm.etch(
            Predeploys.L1_FEE_VAULT,
            address(
                new L1FeeVault(cfg.l1FeeVaultRecipient(), cfg.l1FeeVaultMinimumWithdrawalAmount(), FeeVault.WithdrawalNetwork.L2)
            ).code
        );

        sequencerFeeVault = SequencerFeeVault(payable(Predeploys.SEQUENCER_FEE_WALLET));
        baseFeeVault = BaseFeeVault(payable(Predeploys.BASE_FEE_VAULT));
        l1FeeVault = L1FeeVault(payable(Predeploys.L1_FEE_VAULT));

        vm.etch(Predeploys.L1_BLOCK_ATTRIBUTES, address(new L1Block()).code);
        l1Block = L1Block(Predeploys.L1_BLOCK_ATTRIBUTES);

        vm.etch(Predeploys.GAS_PRICE_ORACLE, address(new GasPriceOracle()).code);
        gasPriceOracle = GasPriceOracle(Predeploys.GAS_PRICE_ORACLE);

        vm.label(Predeploys.OPTIMISM_MINTABLE_ERC20_FACTORY, "OptimismMintableERC20Factory");
        vm.label(Predeploys.LEGACY_ERC20_ETH, "LegacyERC20ETH");
        vm.label(Predeploys.L2_STANDARD_BRIDGE, "L2StandardBridge");
        vm.label(Predeploys.L2_CROSS_DOMAIN_MESSENGER, "L2CrossDomainMessenger");
        vm.label(Predeploys.L2_TO_L1_MESSAGE_PASSER, "L2ToL1MessagePasser");
        vm.label(Predeploys.SEQUENCER_FEE_WALLET, "SequencerFeeVault");
        vm.label(Predeploys.L2_ERC721_BRIDGE, "L2ERC721Bridge");
        vm.label(Predeploys.BASE_FEE_VAULT, "BaseFeeVault");
        vm.label(Predeploys.L1_FEE_VAULT, "L1FeeVault");
        vm.label(Predeploys.L1_BLOCK_ATTRIBUTES, "L1Block");
        vm.label(Predeploys.GAS_PRICE_ORACLE, "GasPriceOracle");
        vm.label(AddressAliasHelper.applyL1ToL2Alias(address(l1CrossDomainMessenger)), "L1CrossDomainMessenger_aliased");
    }

    function emitTransactionDeposited(
        address _from,
        address _to,
        uint256 _mint,
        uint256 _value,
        uint64 _gasLimit,
        bool _isCreation,
        bytes memory _data
    )
        internal
    {
        emit TransactionDeposited(_from, _to, 0, abi.encodePacked(_mint, _value, _gasLimit, _isCreation, _data));
    }
}

contract L2OutputOracle_Initializer is CommonTest {
    event OutputProposed(
        bytes32 indexed outputRoot, uint256 indexed l2OutputIndex, uint256 indexed l2BlockNumber, uint256 l1Timestamp
    );

    event OutputsDeleted(uint256 indexed prevNextOutputIndex, uint256 indexed newNextOutputIndex);

    // @dev Advance the evm's time to meet the L2OutputOracle's requirements for proposeL2Output
    function warpToProposeTime(uint256 _nextBlockNumber) public {
        vm.warp(l2OutputOracle.computeL2Timestamp(_nextBlockNumber) + 1);
    }

    /// @dev Helper function to propose an output.
    function proposeAnotherOutput() public {
        bytes32 proposedOutput2 = keccak256(abi.encode());
        uint256 nextBlockNumber = l2OutputOracle.nextBlockNumber();
        uint256 nextOutputIndex = l2OutputOracle.nextOutputIndex();
        warpToProposeTime(nextBlockNumber);
        uint256 proposedNumber = l2OutputOracle.latestBlockNumber();

        uint256 submissionInterval = cfg.l2OutputOracleSubmissionInterval();
        // Ensure the submissionInterval is enforced
        assertEq(nextBlockNumber, proposedNumber + submissionInterval);

        vm.roll(nextBlockNumber + 1);

        vm.expectEmit(true, true, true, true);
        emit OutputProposed(proposedOutput2, nextOutputIndex, nextBlockNumber, block.timestamp);

        address proposer = cfg.l2OutputOracleProposer();
        vm.prank(proposer);
        l2OutputOracle.proposeL2Output(proposedOutput2, nextBlockNumber, 0, 0);
    }

    function setUp() public virtual override {
        super.setUp();

        // By default the first block has timestamp and number zero, which will cause underflows in the
        // tests, so we'll move forward to these block values.
        vm.warp(cfg.l2OutputOracleStartingTimestamp() + 1);
        vm.roll(cfg.l2OutputOracleStartingBlockNumber() + 1);
    }
}

contract Portal_Initializer is L2OutputOracle_Initializer {
    event WithdrawalFinalized(bytes32 indexed withdrawalHash, bool success);
    event WithdrawalProven(bytes32 indexed withdrawalHash, address indexed from, address indexed to);
}

contract Messenger_Initializer is Portal_Initializer {
    event SentMessage(address indexed target, address sender, bytes message, uint256 messageNonce, uint256 gasLimit);
    event SentMessageExtension1(address indexed sender, uint256 value);
    event MessagePassed(
        uint256 indexed nonce,
        address indexed sender,
        address indexed target,
        uint256 value,
        uint256 gasLimit,
        bytes data,
        bytes32 withdrawalHash
    );
    event RelayedMessage(bytes32 indexed msgHash);
    event FailedRelayedMessage(bytes32 indexed msgHash);
    event TransactionDeposited(
        address indexed from,
        address indexed to,
        uint256 mint,
        uint256 value,
        uint64 gasLimit,
        bool isCreation,
        bytes data
    );
    event WhatHappened(bool success, bytes returndata);
}

contract Bridge_Initializer is Messenger_Initializer {
    ERC20 L1Token;
    ERC20 BadL1Token;
    OptimismMintableERC20 L2Token;
    LegacyMintableERC20 LegacyL2Token;
    ERC20 NativeL2Token;
    ERC20 BadL2Token;
    OptimismMintableERC20 RemoteL1Token;

    event ETHDepositInitiated(address indexed from, address indexed to, uint256 amount, bytes data);

    event ETHWithdrawalFinalized(address indexed from, address indexed to, uint256 amount, bytes data);

    event ERC20DepositInitiated(
        address indexed l1Token, address indexed l2Token, address indexed from, address to, uint256 amount, bytes data
    );

    event ERC20WithdrawalFinalized(
        address indexed l1Token, address indexed l2Token, address indexed from, address to, uint256 amount, bytes data
    );

    event WithdrawalInitiated(
        address indexed l1Token, address indexed l2Token, address indexed from, address to, uint256 amount, bytes data
    );

    event DepositFinalized(
        address indexed l1Token, address indexed l2Token, address indexed from, address to, uint256 amount, bytes data
    );

    event DepositFailed(
        address indexed l1Token, address indexed l2Token, address indexed from, address to, uint256 amount, bytes data
    );

    event ETHBridgeInitiated(address indexed from, address indexed to, uint256 amount, bytes data);

    event ETHBridgeFinalized(address indexed from, address indexed to, uint256 amount, bytes data);

    event ERC20BridgeInitiated(
        address indexed localToken,
        address indexed remoteToken,
        address indexed from,
        address to,
        uint256 amount,
        bytes data
    );

    event ERC20BridgeFinalized(
        address indexed localToken,
        address indexed remoteToken,
        address indexed from,
        address to,
        uint256 amount,
        bytes data
    );

    function setUp() public virtual override {
        super.setUp();

        L1Token = new ERC20("Native L1 Token", "L1T");

        LegacyL2Token = new LegacyMintableERC20({
            _l2Bridge: address(l2StandardBridge),
            _l1Token: address(L1Token),
            _name: string.concat("LegacyL2-", L1Token.name()),
            _symbol: string.concat("LegacyL2-", L1Token.symbol())
        });
        vm.label(address(LegacyL2Token), "LegacyMintableERC20");

        // Deploy the L2 ERC20 now
        L2Token = OptimismMintableERC20(
            l2OptimismMintableERC20Factory.createStandardL2Token(
                address(L1Token),
                string(abi.encodePacked("L2-", L1Token.name())),
                string(abi.encodePacked("L2-", L1Token.symbol()))
            )
        );

        BadL2Token = OptimismMintableERC20(
            l2OptimismMintableERC20Factory.createStandardL2Token(
                address(1),
                string(abi.encodePacked("L2-", L1Token.name())),
                string(abi.encodePacked("L2-", L1Token.symbol()))
            )
        );

        NativeL2Token = new ERC20("Native L2 Token", "L2T");

        RemoteL1Token = OptimismMintableERC20(
            l1OptimismMintableERC20Factory.createStandardL2Token(
                address(NativeL2Token),
                string(abi.encodePacked("L1-", NativeL2Token.name())),
                string(abi.encodePacked("L1-", NativeL2Token.symbol()))
            )
        );

        BadL1Token = OptimismMintableERC20(
            l1OptimismMintableERC20Factory.createStandardL2Token(
                address(1),
                string(abi.encodePacked("L1-", NativeL2Token.name())),
                string(abi.encodePacked("L1-", NativeL2Token.symbol()))
            )
        );
    }
}

contract FeeVault_Initializer is Bridge_Initializer {
    event Withdrawal(uint256 value, address to, address from);
    event Withdrawal(uint256 value, address to, address from, FeeVault.WithdrawalNetwork withdrawalNetwork);
}

contract FFIInterface is Test {
    function getProveWithdrawalTransactionInputs(Types.WithdrawalTransaction memory _tx)
        external
        returns (bytes32, bytes32, bytes32, bytes32, bytes[] memory)
    {
        string[] memory cmds = new string[](9);
        cmds[0] = "scripts/go-ffi/go-ffi";
        cmds[1] = "diff";
        cmds[2] = "getProveWithdrawalTransactionInputs";
        cmds[3] = vm.toString(_tx.nonce);
        cmds[4] = vm.toString(_tx.sender);
        cmds[5] = vm.toString(_tx.target);
        cmds[6] = vm.toString(_tx.value);
        cmds[7] = vm.toString(_tx.gasLimit);
        cmds[8] = vm.toString(_tx.data);

        bytes memory result = vm.ffi(cmds);
        (
            bytes32 stateRoot,
            bytes32 storageRoot,
            bytes32 outputRoot,
            bytes32 withdrawalHash,
            bytes[] memory withdrawalProof
        ) = abi.decode(result, (bytes32, bytes32, bytes32, bytes32, bytes[]));

        return (stateRoot, storageRoot, outputRoot, withdrawalHash, withdrawalProof);
    }

    function hashCrossDomainMessage(
        uint256 _nonce,
        address _sender,
        address _target,
        uint256 _value,
        uint256 _gasLimit,
        bytes memory _data
    )
        external
        returns (bytes32)
    {
        string[] memory cmds = new string[](9);
        cmds[0] = "scripts/go-ffi/go-ffi";
        cmds[1] = "diff";
        cmds[2] = "hashCrossDomainMessage";
        cmds[3] = vm.toString(_nonce);
        cmds[4] = vm.toString(_sender);
        cmds[5] = vm.toString(_target);
        cmds[6] = vm.toString(_value);
        cmds[7] = vm.toString(_gasLimit);
        cmds[8] = vm.toString(_data);

        bytes memory result = vm.ffi(cmds);
        return abi.decode(result, (bytes32));
    }

    function hashWithdrawal(
        uint256 _nonce,
        address _sender,
        address _target,
        uint256 _value,
        uint256 _gasLimit,
        bytes memory _data
    )
        external
        returns (bytes32)
    {
        string[] memory cmds = new string[](9);
        cmds[0] = "scripts/go-ffi/go-ffi";
        cmds[1] = "diff";
        cmds[2] = "hashWithdrawal";
        cmds[3] = vm.toString(_nonce);
        cmds[4] = vm.toString(_sender);
        cmds[5] = vm.toString(_target);
        cmds[6] = vm.toString(_value);
        cmds[7] = vm.toString(_gasLimit);
        cmds[8] = vm.toString(_data);

        bytes memory result = vm.ffi(cmds);
        return abi.decode(result, (bytes32));
    }

    function hashOutputRootProof(
        bytes32 _version,
        bytes32 _stateRoot,
        bytes32 _messagePasserStorageRoot,
        bytes32 _latestBlockhash
    )
        external
        returns (bytes32)
    {
        string[] memory cmds = new string[](7);
        cmds[0] = "scripts/go-ffi/go-ffi";
        cmds[1] = "diff";
        cmds[2] = "hashOutputRootProof";
        cmds[3] = Strings.toHexString(uint256(_version));
        cmds[4] = Strings.toHexString(uint256(_stateRoot));
        cmds[5] = Strings.toHexString(uint256(_messagePasserStorageRoot));
        cmds[6] = Strings.toHexString(uint256(_latestBlockhash));

        bytes memory result = vm.ffi(cmds);
        return abi.decode(result, (bytes32));
    }

    function hashDepositTransaction(
        address _from,
        address _to,
        uint256 _mint,
        uint256 _value,
        uint64 _gas,
        bytes memory _data,
        uint64 _logIndex
    )
        external
        returns (bytes32)
    {
        string[] memory cmds = new string[](11);
        cmds[0] = "scripts/go-ffi/go-ffi";
        cmds[1] = "diff";
        cmds[2] = "hashDepositTransaction";
        cmds[3] = "0x0000000000000000000000000000000000000000000000000000000000000000";
        cmds[4] = vm.toString(_logIndex);
        cmds[5] = vm.toString(_from);
        cmds[6] = vm.toString(_to);
        cmds[7] = vm.toString(_mint);
        cmds[8] = vm.toString(_value);
        cmds[9] = vm.toString(_gas);
        cmds[10] = vm.toString(_data);

        bytes memory result = vm.ffi(cmds);
        return abi.decode(result, (bytes32));
    }

    function encodeDepositTransaction(Types.UserDepositTransaction calldata txn) external returns (bytes memory) {
        string[] memory cmds = new string[](12);
        cmds[0] = "scripts/go-ffi/go-ffi";
        cmds[1] = "diff";
        cmds[2] = "encodeDepositTransaction";
        cmds[3] = vm.toString(txn.from);
        cmds[4] = vm.toString(txn.to);
        cmds[5] = vm.toString(txn.value);
        cmds[6] = vm.toString(txn.mint);
        cmds[7] = vm.toString(txn.gasLimit);
        cmds[8] = vm.toString(txn.isCreation);
        cmds[9] = vm.toString(txn.data);
        cmds[10] = vm.toString(txn.l1BlockHash);
        cmds[11] = vm.toString(txn.logIndex);

        bytes memory result = vm.ffi(cmds);
        return abi.decode(result, (bytes));
    }

    function encodeCrossDomainMessage(
        uint256 _nonce,
        address _sender,
        address _target,
        uint256 _value,
        uint256 _gasLimit,
        bytes memory _data
    )
        external
        returns (bytes memory)
    {
        string[] memory cmds = new string[](9);
        cmds[0] = "scripts/go-ffi/go-ffi";
        cmds[1] = "diff";
        cmds[2] = "encodeCrossDomainMessage";
        cmds[3] = vm.toString(_nonce);
        cmds[4] = vm.toString(_sender);
        cmds[5] = vm.toString(_target);
        cmds[6] = vm.toString(_value);
        cmds[7] = vm.toString(_gasLimit);
        cmds[8] = vm.toString(_data);

        bytes memory result = vm.ffi(cmds);
        return abi.decode(result, (bytes));
    }

    function decodeVersionedNonce(uint256 nonce) external returns (uint256, uint256) {
        string[] memory cmds = new string[](4);
        cmds[0] = "scripts/go-ffi/go-ffi";
        cmds[1] = "diff";
        cmds[2] = "decodeVersionedNonce";
        cmds[3] = vm.toString(nonce);

        bytes memory result = vm.ffi(cmds);
        return abi.decode(result, (uint256, uint256));
    }

    function getMerkleTrieFuzzCase(string memory variant)
        external
        returns (bytes32, bytes memory, bytes memory, bytes[] memory)
    {
        string[] memory cmds = new string[](6);
        cmds[0] = "./scripts/go-ffi/go-ffi";
        cmds[1] = "trie";
        cmds[2] = variant;

        return abi.decode(vm.ffi(cmds), (bytes32, bytes, bytes, bytes[]));
    }

    function getCannonMemoryProof(uint32 pc, uint32 insn) external returns (bytes32, bytes memory) {
        string[] memory cmds = new string[](5);
        cmds[0] = "scripts/go-ffi/go-ffi";
        cmds[1] = "diff";
        cmds[2] = "cannonMemoryProof";
        cmds[3] = vm.toString(pc);
        cmds[4] = vm.toString(insn);
        bytes memory result = vm.ffi(cmds);
        (bytes32 memRoot, bytes memory proof) = abi.decode(result, (bytes32, bytes));
        return (memRoot, proof);
    }

    function getCannonMemoryProof(
        uint32 pc,
        uint32 insn,
        uint32 memAddr,
        uint32 memVal
    )
        external
        returns (bytes32, bytes memory)
    {
        string[] memory cmds = new string[](7);
        cmds[0] = "scripts/go-ffi/go-ffi";
        cmds[1] = "diff";
        cmds[2] = "cannonMemoryProof";
        cmds[3] = vm.toString(pc);
        cmds[4] = vm.toString(insn);
        cmds[5] = vm.toString(memAddr);
        cmds[6] = vm.toString(memVal);
        bytes memory result = vm.ffi(cmds);
        (bytes32 memRoot, bytes memory proof) = abi.decode(result, (bytes32, bytes));
        return (memRoot, proof);
    }
}

library EIP1967Helper {
    Vm internal constant vm = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function getAdmin(address _proxy) internal view returns (address) {
        return address(uint160(uint256(vm.load(address(_proxy), Constants.PROXY_OWNER_ADDRESS))));
    }

    function getImplementation(address _proxy) internal view returns (address) {
        return address(uint160(uint256(vm.load(address(_proxy), Constants.PROXY_IMPLEMENTATION_ADDRESS))));
    }
}

// Used for testing a future upgrade beyond the current implementations.
// We include some variables so that we can sanity check accessing storage values after an upgrade.
contract NextImpl is Initializable {
    // Initializable occupies the zero-th slot.
    bytes32 slot1;
    bytes32[19] __gap;
    bytes32 slot21;
    bytes32 public constant slot21Init = bytes32(hex"1337");

    function initialize(uint8 _init) public reinitializer(_init) {
        // Slot21 is unused by an of our upgradeable contracts.
        // This is used to verify that we can access this value after an upgrade.
        slot21 = slot21Init;
    }
}

contract Reverter {
    fallback() external {
        revert();
    }
}

// Useful for testing reentrancy guards
contract CallerCaller {
    event WhatHappened(bool success, bytes returndata);

    fallback() external {
        (bool success, bytes memory returndata) = msg.sender.call(msg.data);
        emit WhatHappened(success, returndata);
        assembly {
            switch success
            case 0 { revert(add(returndata, 0x20), mload(returndata)) }
            default { return(add(returndata, 0x20), mload(returndata)) }
        }
    }
}

// Used for testing the `CrossDomainMessenger`'s per-message reentrancy guard.
contract ConfigurableCaller {
    bool doRevert = true;
    address target;
    bytes payload;

    event WhatHappened(bool success, bytes returndata);

    /// @notice Call the configured target with the configured payload OR revert.
    function call() external {
        if (doRevert) {
            revert("ConfigurableCaller: revert");
        } else {
            (bool success, bytes memory returndata) = address(target).call(payload);
            emit WhatHappened(success, returndata);
            assembly {
                switch success
                case 0 { revert(add(returndata, 0x20), mload(returndata)) }
                default { return(add(returndata, 0x20), mload(returndata)) }
            }
        }
    }

    /// @notice Set whether or not to have `call` revert.
    function setDoRevert(bool _doRevert) external {
        doRevert = _doRevert;
    }

    /// @notice Set the target for the call made in `call`.
    function setTarget(address _target) external {
        target = _target;
    }

    /// @notice Set the payload for the call made in `call`.
    function setPayload(bytes calldata _payload) external {
        payload = _payload;
    }

    /// @notice Fallback function that reverts if `doRevert` is true.
    ///        Otherwise, it does nothing.
    fallback() external {
        if (doRevert) {
            revert("ConfigurableCaller: revert");
        }
    }
}

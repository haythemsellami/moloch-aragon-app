pragma solidity ^0.4.24;

import "@aragon/os/contracts/apps/AragonApp.sol";
import "@aragon/apps-agent/contracts/Agent.sol";


contract Moloch is AragonApp {

    bytes32 public constant SET_AGENT_ROLE = keccak256("SET_AGENT_ROLE");
    bytes32 public constant SET_MOLOCH_ROLE = keccack256("SET_MOLOCH_ROLE");
    bytes32 public constant VOTE_ROLE = keccak256("VOTE_ROLE");
    bytes32 public constant RAGE_QUIT_ROLE = keccak256("RAGE_QUIT_ROLE");

    string private constant ERROR_NOT_CONTRACT = "ERROR_NOT_CONTRACT";
    string private constant ERROR_AGENT_SUBMIT_PROPOSAL= "ERROR_AGENT_SUBMIT_PROPOSAL";
    string private constant ERROR_AGENT_VOTE = "ERROR_AGENT_VOTE";

    Agent public agent;
    address public molochContract;

    event AppInitialized();
    event NewAgentSet(address indexed);
    event AgentSubmitProposal();
    event AgentVote(uint256 indexed);
    event AgentRageQuit();

    /**
    * @notice Initialize the Moloch App
    * @param _agent The Agent contract address
    */
    function initialize(
        address _moloch,
        address _agent
    ) external onlyInit
    {
        require(isContract(_moloch), ERROR_NOT_CONTRACT);
        require(isContract(_agent), ERROR_NOT_CONTRACT);

        molochContract = _moloch;
        agent = Agent(_agent);
        initialized();

        emit AppInitialized();
    }

    /**
    * @notice Update the Moloch address to `_moloch`
    * @param _agent New Agent address
    */
    function setMoloch(
        address _moloch
    ) external auth(SET_MOLOCH_ROLE)
    {
        require(isContract(_moloch), ERROR_NOT_CONTRACT);

        molochContract = _moloch;
        emit NewAgentSet(_agent);
    }

    /**
    * @notice Update the Agent address to `_agent`
    * @param _agent New Agent address
    */
    function setAgent(
        address _agent
    ) external auth(SET_AGENT_ROLE)
    {
        require(isContract(_agent), ERROR_NOT_CONTRACT);

        agent = Agent(_agent);
        emit NewAgentSet(_agent);
    }

    function submitProposal(
        address _applicant,
        uint256 _tokenTribute,
        uint256 _sharesRequested,
        string memory _details
    ) external auth(SUBMIT_VOTE_ROLE)
    {
        bytes memory submitProposalFunctionCall = abi.encodeWithSignature(
            "submitProposal(address,uint256,uint256,string)",
            _applicant,
            _tokenTribute,
            _sharesRequested,
            _details
        );
        agent.safeExecuteNoError(molochContract, submitProposalFunctionCall, ERROR_AGENT_SUBMIT_PROPOSAL);

        emit AgentSubmitProposal();
    }

    function vote(
        uint256 proposalIndex,
        uint8 uintVote
    ) external auth(VOTE_ROLE)
    {
        bytes memory submitVoteFunctionCall = abi.encodeWithSignature("submitVote(uint256,uint8)", _proposalIndex, _uintVote);
        agent.safeExecuteNoError(molochContract, submitVoteFunctionCall, ERROR_AGENT_VOTE);

        emit AgentVote(proposalIndex);
    }

    /**
    * @notice Ensure the returned uint256 from the _data call is 0, representing a successful call
    * @param _target Address where the action is being executed
    * @param _data Calldata for the action
    */
    function safeExecuteNoError(
        address _target,
        bytes _data,
        string memory _error
    ) internal
    {
        agent.safeExecute(_target, _data);

        uint256 callReturnValue;

        assembly {
            switch returndatasize                 // get return data size from the previous call
            case 0x20 {                           // if the return data size is 32 bytes (1 word/uint256)
                let output := mload(0x40)         // get a free memory pointer
                mstore(0x40, add(output, 0x20))   // set the free memory pointer 32 bytes
                returndatacopy(output, 0, 0x20)   // copy the first 32 bytes of data into output
                callReturnValue := mload(output)  // read the data from output
            }
            default {
                revert(0, 0) // revert on unexpected return data size
            }
        }

        require(callReturnValue == 0, _error);
    }

}
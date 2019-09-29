pragma solidity 0.4.24;

import "@aragon/os/contracts/factory/DAOFactory.sol";
import "@aragon/os/contracts/apm/Repo.sol";
import "@aragon/os/contracts/lib/ens/ENS.sol";
import "@aragon/os/contracts/lib/ens/PublicResolver.sol";
import "@aragon/os/contracts/apm/APMNamehash.sol";

import "@aragon/apps-voting/contracts/Voting.sol";
import "@aragon/apps-agent/contracts/Agent.sol";

import "./Moloch.sol";


contract TemplateBase is APMNamehash {
    ENS public ens;
    DAOFactory public fac;

    event DeployInstance(address dao);
    event InstalledApp(address appProxy, bytes32 appId);

    constructor(DAOFactory _fac, ENS _ens) public {
        ens = _ens;

        // If no factory is passed, get it from on-chain bare-kit
        if (address(_fac) == address(0)) {
            bytes32 bareKit = apmNamehash("bare-kit");
            fac = TemplateBase(latestVersionAppBase(bareKit)).fac();
        } else {
            fac = _fac;
        }
    }

    function latestVersionAppBase(bytes32 appId) public view returns (address base) {
        Repo repo = Repo(PublicResolver(ens.resolver(appId)).addr(appId));
        (,base,) = repo.getLatest();

        return base;
    }
}


contract Template is TemplateBase {

    uint64 constant PCT = 10 ** 16;
    address constant ANY_ENTITY = address(-1);

    constructor(ENS ens) TemplateBase(DAOFactory(0), ens) public {
    }

    function newInstance() public {
        Kernel dao = fac.newDAO(this);
        ACL acl = ACL(dao.acl());
        acl.createPemission(this, dao, dao.APP_MANAGER_ROLE(), this);

        address root = msg.sender;
        bytes32 molochAppId = keccak256(abi.encodePacked(apmNamehash("open"), keccak256("moloch")));
        bytes32 votingAppId = apmNamehash("voting");
        bytes32 agentAppId = apmNamehash("agent");

        Moloch moloch = Moloch(dao.newAppInstance(molochAppId, latestVersionAppBase(molochAppId)));
        Voting voting = Voting(dao.newAppInstance(votingAppId, latestVersionAppBase(votingAppId)));
        Agent agent = Agent(dao.newAppInstance(agentAppId, latestVersionAppBase(agentAppId)));

        // Initialize apps
        moloch.initialize();
        voting.initialize(token, 50 * PCT, 20 * PCT, 1 days);
        agent.initialize();

        // ACL permissions
        acl.createPermission(ANY_ENTITY, voting, voting.CREATE_VOTES_ROLE(), root);

        acl.createPermission(root, moloch, moloch.SET_AGENT_ROLE(), root);
        acl.createPermission(root, moloch, moloch.SET_MOLOCH_ROLE(), root);

        acl.createPermission(voting, moloch, moloch.PROPOSAL_ROLE(), voting);
        acl.createPermission(voting, moloch, moloch.VOTE_ROLE(), voting);
        acl.createPermission(voting, moloch, moloch.RAGE_QUIT_ROLE(), voting);
        acl.createPermission(voting, moloch, moloch.ABORT_ROLE(), voting);

        acl.createPermission(address(moloch), agent, agent.EXECUTE_ROLE(), root);
        acl.createPermission(address(moloch), agent, agent.SAFE_EXECUTE_ROLE(), root);
        acl.createPermission(address(moloch), agent, agent.TRANSFER_ROLE(), root);

        // Clean up permissions
        acl.grantPermission(root, dao, dao.APP_MANAGER_ROLE());
        acl.revokePermission(this, dao, dao.APP_MANAGER_ROLE());
        acl.setPermissionManager(root, dao, dao.APP_MANAGER_ROLE());

        acl.grantPermission(root, acl, acl.CREATE_PERMISSIONS_ROLE());
        acl.revokePermission(this, acl, acl.CREATE_PERMISSIONS_ROLE());
        acl.setPermissionManager(root, acl, acl.CREATE_PERMISSIONS_ROLE());

        emit DeployInstance(dao);
    }
}

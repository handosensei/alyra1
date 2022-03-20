// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";

contract Voting is Ownable {
    
    // ====== INIT PROJECT =====
    event WorkflowStatusChange(WorkflowStatus previousStatus, WorkflowStatus nextStatus);
    event ProposalRegistered(uint proposalId);
    event Voted (address voter, uint proposalId);
    event VoterRegistered(address voterAddress, uint addressLength); 
    
    uint winningProposalId;

    struct Voter {
        bool isRegistered;
        bool hasVoted;
        uint votedProposalId;
    }

    struct Proposal {
        string description;
        uint voteCount;
    }

    enum WorkflowStatus {
        RegisteringVoters,
        ProposalsRegistrationStarted,
        ProposalsRegistrationEnded,
        VotingSessionStarted,
        VotingSessionEnded,
        VotesTallied
    }

    // ====== END INIT PROJECT =====    
    WorkflowStatus currentStatus;
    mapping(WorkflowStatus => WorkflowStatus) workflow;

    mapping(address => Voter) electors;
    address[] public electorsAddresses;
    
    mapping(uint => Proposal) public candidates ;
    uint nextProposalId;

    constructor() {
        buildWorkflow();
        currentStatus = WorkflowStatus.RegisteringVoters;
        nextProposalId = 0;
    }

    // Gestion du WORKFLOW
    function buildWorkflow() internal {
        workflow[WorkflowStatus.RegisteringVoters] = WorkflowStatus.ProposalsRegistrationStarted;
        workflow[WorkflowStatus.ProposalsRegistrationStarted] = WorkflowStatus.ProposalsRegistrationEnded;
        workflow[WorkflowStatus.ProposalsRegistrationEnded] = WorkflowStatus.VotingSessionStarted;
        workflow[WorkflowStatus.VotingSessionStarted] = WorkflowStatus.VotingSessionEnded;
        workflow[WorkflowStatus.VotingSessionEnded] = WorkflowStatus.VotesTallied;
    }    

    function getWorkflowStatus() public view returns(WorkflowStatus) {
        return currentStatus;
    }

    function nextWorkflowStatus() public onlyOwner {
        require(currentStatus != WorkflowStatus.VotesTallied, "Last workflow step");
        WorkflowStatus previousStatus = currentStatus;
        currentStatus = workflow[currentStatus];

        emit WorkflowStatusChange(previousStatus, workflow[currentStatus]);
    }
    
    // Gestion du VOTE
    function addVoter(address _address) public onlyOwner {
        require(currentStatus == WorkflowStatus.RegisteringVoters, "Too late to register voter");
        //require(canRegister(_address), "Already register");

        electors[_address] = Voter(true, false, 0);
        electorsAddresses.push(_address);

        emit VoterRegistered(_address, electorsAddresses.length); 
    }
    
    /*
    function canRegister(address _address) public view returns(bool) {
        for (uint index = 0; index < electorsAddresses.length - 1; index++) {
            if (electorsAddresses[index] == _address) {
                return false;
            }
        }

        return true;
    }
    */

    function countVoter() public view returns(uint) {
        return electorsAddresses.length;
    }

    function getVotedProposalIdByVoter(address _address) public view returns(uint) {
        return electors[_address].votedProposalId;
    }
    
    function vote(uint _proposalId) public  {
        require(currentStatus == WorkflowStatus.VotingSessionStarted, "Session close");
        require(electors[msg.sender].isRegistered, "No register");
        require(electors[msg.sender].hasVoted == false, "only one VOTE");

        candidates[_proposalId].voteCount++;
        
        electors[msg.sender].hasVoted = true;
        electors[msg.sender].votedProposalId = _proposalId;

        emit Voted(msg.sender, _proposalId);
    }

     // Gestion des PROPOSALS
    function addProposal(string memory _description) public {
        require(currentStatus == WorkflowStatus.ProposalsRegistrationStarted, "Proposal registration close");
        candidates[nextProposalId] = Proposal(_description, 0);
        
        emit ProposalRegistered(nextProposalId);

        nextProposalId++;
    }

    function getProposalDescription(uint _proposalId) public view returns(string memory) {
        return candidates[_proposalId].description;
    }

    function getProposalVoteCount(uint _proposalId) public view returns(uint) {
        return candidates[_proposalId].voteCount;
    }

    // Gestion du compte des votes
    function runProposalVoteCount() public onlyOwner {
        require(currentStatus == WorkflowStatus.VotingSessionEnded, "Pas le moment de compter");
        
        uint maxVote = 0;
        uint tempWinnerProposalId = 0;
        for (uint index = 0; index < nextProposalId; index++) {
            if (candidates[index].voteCount < maxVote) {
                continue;
            }
            maxVote = candidates[index].voteCount;
            tempWinnerProposalId = index;
        }

        winningProposalId = tempWinnerProposalId;
        
        nextWorkflowStatus();
    } 

    function getWinner() public view returns(uint) {
        require(currentStatus == WorkflowStatus.VotesTallied, "Comptabiliter des votes non executer");

        return winningProposalId;
    }
}

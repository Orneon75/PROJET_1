// SPDX-License-Identifier: MIT

// Derniere version du compilateur 0.8.37 sur REMIX
pragma solidity 0.8.37;

// Import de la librairie “Ownable” d’OpenZepplin
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";


// EVOLUTION A FAIRE
// GetVoter
// GetProposal
// GetWorkflowStatus pour savoir où j'en suis dans mon test car renvoie 0,1, 2 ...
// Donner au owner la possibilité de revenir en arrière sur le workflow status 
// test description non vide + test description non déjà proposée ( à l'identique (HASH) ? proche sémantique ?)
/////////////////////////////////////////////////////////////////


contract Voting is Ownable{

    
    //Structure du votant
    struct Voter {
        bool  isRegistered ;         // personne enregistré
        bool  hasVoted ;             // a voté TRUE / FALSE
        uint  votedProposalId ;      //
    } 

    //Structure de la proposition
    struct Proposal {
        string  description ;        // Description de la proposition
        uint    votecount ;          // Nb de vote
    } 

    //Décalaration d’une énumération WorkflowStatus qui définit 6 états 
    //Enregistrement des électeurs, Début de l'enregistrement des propositions, Fin de l'enregistrement des propositions, 
    //Début de la session de vote, Fin de la session de vote, Dépouillement des votes
    enum WorkflowStatus { 
        RegisteringVoters, 
        ProposalsRegistrationStarted, 
        ProposalsRegistrationEnded, 
        VotingSessionStarted, 
        VotingSessionEnded, 
        VotesTallied } 

    
    
    //WorkflowStatus public defaultstate = WorkflowStatus.RegisteringVoters;
    WorkflowStatus public workflowStatus;
    uint winningProposalId ;               // On part du principe qu'une seule proposition gagnante mais on pourrait avoir plusieurs propositions 
    Proposal[] public proposals;
    mapping(address=> Voter) public voters;

    //Event
    event VoterRegistered(address voterAddress);
    event WorkflowStatusChange(WorkflowStatus previousStatus, WorkflowStatus newStatus);
    event ProposalRegistered(uint proposalId);
    event Voted(address voter, uint proposalId);

    //Modifier
    //Vérification si le votant est enregistré
    modifier RegisteredVoter () {
        require(voters[msg.sender].isRegistered, "Unregistered voter");
        _;
    }

    modifier CompareStatus(WorkflowStatus _status) {
        require(workflowStatus == _status, "Workflow status mismatch");
        _;
    }

    //L’administrateur est celui qui va déployer le smart contract. 
    //on initialise le statut à "RegisteringVoters"
    constructor() Ownable(msg.sender){  
        workflowStatus = WorkflowStatus.RegisteringVoters;
    }


    //Step 1 Enregistrement des votants uniquement enregistés durant le statut "RegisteringVoters" par l'administrateur
    function AddVoter(address _voterAddress) public onlyOwner CompareStatus(WorkflowStatus.RegisteringVoters) {
        require(!voters[_voterAddress].isRegistered, "Already registered voter");
        require(_voterAddress != address(0), "Invalid address");
        
        voters[_voterAddress].isRegistered = true;
        emit VoterRegistered(_voterAddress);
    }

    //Step 2 On passe au statut ProposalsRegistrationStarted
    function startProposalsRegistration() public onlyOwner CompareStatus(WorkflowStatus.RegisteringVoters) {
        workflowStatus = WorkflowStatus.ProposalsRegistrationStarted;
        emit WorkflowStatusChange(WorkflowStatus.RegisteringVoters, WorkflowStatus.ProposalsRegistrationStarted);
    }

    //Step 3 Enregistrement des propositions
    function AddProposal(string memory _description) public onlyOwner CompareStatus(WorkflowStatus.ProposalsRegistrationStarted) {
        Proposal memory proposal = Proposal(_description, 0);    //création d'un nouvel objet
        proposals.push(proposal);                                // Ajout de l'objet "Proposal" dans le tableau

        emit ProposalRegistered(proposals.length - 1);               // on renvoie l'indice du tableau qui fera office d'Id
    }

    //Step 4 Fin des Enregistrements des propositions
    function StopProposalsRegistration() public onlyOwner CompareStatus(WorkflowStatus.ProposalsRegistrationStarted) {
        workflowStatus = WorkflowStatus.ProposalsRegistrationEnded;
        emit WorkflowStatusChange(WorkflowStatus.ProposalsRegistrationStarted, WorkflowStatus.ProposalsRegistrationEnded);
    }

    //Step 5 Démarrage de la session de vote
    function StartVoteSession() public onlyOwner CompareStatus(WorkflowStatus.ProposalsRegistrationEnded) {
        workflowStatus = WorkflowStatus.VotingSessionStarted;
        emit WorkflowStatusChange(WorkflowStatus.ProposalsRegistrationEnded, WorkflowStatus.VotingSessionStarted);
    }

    //Step 6 Démarrage des votes pour les propositions
    function StartVote(uint _proposalId) public RegisteredVoter CompareStatus(WorkflowStatus.VotingSessionStarted) {
        require(!voters[msg.sender].hasVoted, "You have already voted");
        require(_proposalId < proposals.length, "Proposal not found");
        voters[msg.sender].hasVoted = true;
        voters[msg.sender].votedProposalId = _proposalId;
        
        proposals[_proposalId].votecount += 1;
        emit Voted(msg.sender, _proposalId);
    }


    // Step 7 Fin de la session de vote
    function EndVoteSession() public onlyOwner CompareStatus(WorkflowStatus.VotingSessionStarted) {
        workflowStatus = WorkflowStatus.VotingSessionEnded;
        emit WorkflowStatusChange(WorkflowStatus.VotingSessionStarted, WorkflowStatus.VotingSessionEnded);
    }

    // Step 8 Dépouillement
    function CountingVote() public onlyOwner CompareStatus(WorkflowStatus.VotingSessionEnded){
        require(proposals.length > 0, "No proposals");

        // On parcourt le tableau de structure de proposition
        uint winningVoteCount = 0;
        for (uint i = 0; i < proposals.length; i++) {
            if (proposals[i].votecount > winningVoteCount) {
                winningVoteCount = proposals[i].votecount;
                winningProposalId = i;
            }
        }

        workflowStatus = WorkflowStatus.VotesTallied;
        emit WorkflowStatusChange(WorkflowStatus.VotingSessionEnded, WorkflowStatus.VotesTallied);
    }
    
    // Récupération des votants
    function getVoter(address _address) external view returns (Voter memory) {
        require(voters[_address].isRegistered, "Address is not registered");
        return voters[_address];
    }
    // Récupération de la proposition gagnante
    function getWinner() public view CompareStatus(WorkflowStatus.VotesTallied) returns (Proposal memory) {
        require(proposals.length > 0, "No proposal");
        return proposals[winningProposalId];
    }

}
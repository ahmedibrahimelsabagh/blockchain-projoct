// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract EduChainCrowdfunding {
    address public immutable owner;
    uint256 public immutable goal;
    uint256 public deadline;
    uint256 public totalRaised;
    bool    public goalReached;
    bool    public fundsWithdrawn;
    uint256 public constant LEARNER_TIER = 0.01 ether;
    uint256 public constant MENTOR_TIER  = 0.05 ether;
    uint256 public constant FOUNDER_TIER = 0.10 ether;
    enum Tier { None, Learner, Mentor, Founder }

    struct Contributor {
        uint256 amount;
        Tier    tier;
        bool    refunded;
    }
    mapping(address => Contributor) public contributors;
    address[] public contributorList;
    event ContributionReceived(address indexed contributor, uint256 amount, Tier tier);
    event GoalReached(uint256 totalRaised);
    event FundsWithdrawn(address indexed owner, uint256 amount);
    event RefundIssued(address indexed contributor, uint256 amount);
    event DeadlineExpired(uint256 at);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner");
        _;
    }
    modifier beforeDeadline() {
        require(block.timestamp < deadline, "Deadline has passed");
        _;
    }
    modifier afterDeadline() {
        require(block.timestamp >= deadline, "Deadline not yet reached");
        _;
    }

    constructor(uint256 _goal, uint256 _durationInSeconds) {
        require(_goal > 0,               "Goal must be greater than 0");
        require(_durationInSeconds > 0,  "Duration must be greater than 0");

        owner    = msg.sender;
        goal     = _goal;
        deadline = block.timestamp + _durationInSeconds;
    }

    function expireForTesting() external onlyOwner {
        require(block.timestamp < deadline, "Deadline already passed");
        deadline = block.timestamp;
        emit DeadlineExpired(deadline);
    }

    function contribute() external payable beforeDeadline {
        require(msg.value > 0, "Contribution must be > 0");

        Contributor storage c = contributors[msg.sender];

        if (c.amount == 0) {
            contributorList.push(msg.sender);
        }

        c.amount += msg.value;
        c.tier    = _calculateTier(c.amount);

        totalRaised += msg.value;

        if (!goalReached && totalRaised >= goal) {
            goalReached = true;
            emit GoalReached(totalRaised);
        }

        emit ContributionReceived(msg.sender, msg.value, c.tier);
    }

    function _calculateTier(uint256 amount) internal pure returns (Tier) {
        if (amount >= FOUNDER_TIER) return Tier.Founder;
        if (amount >= MENTOR_TIER)  return Tier.Mentor;
        if (amount >= LEARNER_TIER) return Tier.Learner;
        return Tier.None;
    }

    function withdraw() external onlyOwner afterDeadline {
        require(goalReached,      "Goal was not reached");
        require(!fundsWithdrawn,  "Funds already withdrawn");

        fundsWithdrawn = true;

        uint256 amount = address(this).balance;
        (bool ok, ) = payable(owner).call{value: amount}("");
        require(ok, "Withdraw transfer failed");

        emit FundsWithdrawn(owner, amount);
    }

    function refund() external afterDeadline {
        require(!goalReached, "Goal reached; refunds disabled");

        Contributor storage c = contributors[msg.sender];
        require(c.amount > 0,  "No contribution to refund");
        require(!c.refunded,   "Already refunded");

        uint256 amount = c.amount;
        c.refunded = true;
        c.amount   = 0;

        (bool ok, ) = payable(msg.sender).call{value: amount}("");
        require(ok, "Refund transfer failed");

        emit RefundIssued(msg.sender, amount);
    }

    function getContribution(address _addr) external view returns (uint256) {
        return contributors[_addr].amount;
    }

    function getTier(address _addr) external view returns (Tier) {
        return contributors[_addr].tier;
    }

    function timeLeft() external view returns (uint256) {
        if (block.timestamp >= deadline) return 0;
        return deadline - block.timestamp;
    }

    function contributorCount() external view returns (uint256) {
        return contributorList.length;
    }
}
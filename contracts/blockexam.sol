// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title BlockExam
 * @dev A decentralized examination system on blockchain
 * @author BlockExam Team
 */
contract BlockExam {
    
    // State variables
    address public owner;
    uint256 public examCounter;
    
    // Structs
    struct Exam {
        uint256 id;
        string title;
        address creator;
        uint256 duration; // in minutes
        uint256 maxScore;
        bool isActive;
        uint256 createdAt;
    }
    
    struct ExamResult {
        address student;
        uint256 examId;
        uint256 score;
        uint256 completedAt;
        bool isVerified;
    }
    
    // Mappings
    mapping(uint256 => Exam) public exams;
    mapping(address => bool) public authorizedExaminers;
    mapping(bytes32 => ExamResult) public results; // keccak256(student, examId) => result
    mapping(uint256 => address[]) public examParticipants;
    
    // Events
    event ExamCreated(uint256 indexed examId, string title, address indexed creator);
    event ExamCompleted(address indexed student, uint256 indexed examId, uint256 score);
    event ResultVerified(address indexed student, uint256 indexed examId, address indexed verifier);
    event ExaminerAuthorized(address indexed examiner, address indexed authorizer);
    
    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can perform this action");
        _;
    }
    
    modifier onlyAuthorizedExaminer() {
        require(authorizedExaminers[msg.sender] || msg.sender == owner, "Not authorized examiner");
        _;
    }
    
    modifier examExists(uint256 _examId) {
        require(_examId > 0 && _examId <= examCounter, "Exam does not exist");
        _;
    }
    
    modifier examActive(uint256 _examId) {
        require(exams[_examId].isActive, "Exam is not active");
        _;
    }
    
    // Constructor
    constructor() {
        owner = msg.sender;
        authorizedExaminers[msg.sender] = true;
        examCounter = 0;
    }
    
    /**
     * @dev Core Function 1: Create a new examination
     * @param _title The title of the examination
     * @param _duration Duration of exam in minutes
     * @param _maxScore Maximum possible score for the exam
     */
    function createExam(
        string memory _title,
        uint256 _duration,
        uint256 _maxScore
    ) external onlyAuthorizedExaminer returns (uint256) {
        require(bytes(_title).length > 0, "Title cannot be empty");
        require(_duration > 0, "Duration must be positive");
        require(_maxScore > 0, "Max score must be positive");
        
        examCounter++;
        
        exams[examCounter] = Exam({
            id: examCounter,
            title: _title,
            creator: msg.sender,
            duration: _duration,
            maxScore: _maxScore,
            isActive: true,
            createdAt: block.timestamp
        });
        
        emit ExamCreated(examCounter, _title, msg.sender);
        return examCounter;
    }
    
    /**
     * @dev Core Function 2: Submit exam result
     * @param _examId The ID of the exam
     * @param _student Address of the student
     * @param _score Score achieved by the student
     */
    function submitResult(
        uint256 _examId,
        address _student,
        uint256 _score
    ) external onlyAuthorizedExaminer examExists(_examId) examActive(_examId) {
        require(_student != address(0), "Invalid student address");
        require(_score <= exams[_examId].maxScore, "Score exceeds maximum");
        
        bytes32 resultKey = keccak256(abi.encodePacked(_student, _examId));
        require(results[resultKey].student == address(0), "Result already exists");
        
        results[resultKey] = ExamResult({
            student: _student,
            examId: _examId,
            score: _score,
            completedAt: block.timestamp,
            isVerified: false
        });
        
        examParticipants[_examId].push(_student);
        
        emit ExamCompleted(_student, _examId, _score);
    }
    
    /**
     * @dev Core Function 3: Verify and authenticate exam results
     * @param _student Address of the student whose result to verify
     * @param _examId The ID of the exam
     */
    function verifyResult(
        address _student,
        uint256 _examId
    ) external onlyAuthorizedExaminer examExists(_examId) {
        require(_student != address(0), "Invalid student address");
        
        bytes32 resultKey = keccak256(abi.encodePacked(_student, _examId));
        require(results[resultKey].student != address(0), "Result not found");
        require(!results[resultKey].isVerified, "Result already verified");
        
        results[resultKey].isVerified = true;
        
        emit ResultVerified(_student, _examId, msg.sender);
    }
    
    // Additional utility functions
    
    /**
     * @dev Authorize a new examiner
     * @param _examiner Address to authorize as examiner
     */
    function authorizeExaminer(address _examiner) external onlyOwner {
        require(_examiner != address(0), "Invalid examiner address");
        require(!authorizedExaminers[_examiner], "Already authorized");
        
        authorizedExaminers[_examiner] = true;
        emit ExaminerAuthorized(_examiner, msg.sender);
    }
    
    /**
     * @dev Deactivate an exam
     * @param _examId The ID of the exam to deactivate
     */
    function deactivateExam(uint256 _examId) external onlyAuthorizedExaminer examExists(_examId) {
        require(exams[_examId].creator == msg.sender || msg.sender == owner, "Not authorized");
        exams[_examId].isActive = false;
    }
    
    /**
     * @dev Get exam details
     * @param _examId The ID of the exam
     */
    function getExam(uint256 _examId) external view examExists(_examId) returns (
        string memory title,
        address creator,
        uint256 duration,
        uint256 maxScore,
        bool isActive,
        uint256 createdAt
    ) {
        Exam memory exam = exams[_examId];
        return (
            exam.title,
            exam.creator,
            exam.duration,
            exam.maxScore,
            exam.isActive,
            exam.createdAt
        );
    }
    
    /**
     * @dev Get student result for specific exam
     * @param _student Address of the student
     * @param _examId The ID of the exam
     */
    function getResult(address _student, uint256 _examId) external view returns (
        uint256 score,
        uint256 completedAt,
        bool isVerified
    ) {
        bytes32 resultKey = keccak256(abi.encodePacked(_student, _examId));
        ExamResult memory result = results[resultKey];
        require(result.student != address(0), "Result not found");
        
        return (result.score, result.completedAt, result.isVerified);
    }
    
    /**
     * @dev Get number of participants for an exam
     * @param _examId The ID of the exam
     */
    function getParticipantCount(uint256 _examId) external view examExists(_examId) returns (uint256) {
        return examParticipants[_examId].length;
    }
    
    /**
     * @dev Get total number of exams created
     */
    function getTotalExams() external view returns (uint256) {
        return examCounter;
    }
}

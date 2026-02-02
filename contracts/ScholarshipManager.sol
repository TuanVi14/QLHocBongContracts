// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ScholarshipManager is Ownable { 
    IERC20 public paymentToken;

    // Địa chỉ Admin tối cao (Người được quyền thêm/xóa trường)
    address constant ADMIN_WALLET = 0x21143185aBb050330F6Da0B5c3f1089A0ab6De93;

    // --- QUẢN LÝ DANH SÁCH NHÀ TRƯỜNG (VERIFIERS) ---
    mapping(address => bool) public isVerifier; // Check nhanh
    address[] public verifierList;              // Lấy danh sách hiển thị

    struct Scholarship {
        uint256 id;
        string title;
        uint256 amount; 
        uint256 slots;
        uint256 filledSlots;
        uint256 deadline; 
        string description;
        uint256 totalApplicants;
        address creator; // [MỚI] Lưu người tạo học bổng
    }

    struct Application {
        address applicant;
        string metadata; 
        Status status;
    }

    // [MỚI] Thêm Verified và Rejected
    enum Status { Created, Applied, Verified, Approved, Paid, Rejected }

    uint256 public nextScholarshipId;
    mapping(uint256 => Scholarship) public scholarships;
    mapping(uint256 => Application[]) public applications;

    // Events
    event ScholarshipCreated(uint256 indexed id, string title, uint256 amount, address creator);
    event Applied(uint256 indexed id, address indexed applicant);
    event Verified(uint256 indexed id, uint256 index, address verifier, bool isValid);
    event Approved(uint256 indexed id, uint256 index, address approver);
    event Paid(uint256 indexed id, uint256 index, address to, uint256 amount);
    event VerifierAdded(address indexed verifier);
    event VerifierRemoved(address indexed verifier);

    // Constructor
    constructor(address _tokenAddress) Ownable(ADMIN_WALLET) {
        require(_tokenAddress != address(0), "Dia chi Token khong hop le");
        paymentToken = IERC20(_tokenAddress);
        
        // Mặc định Admin cũng là Verifier để test cho dễ
        _addVerifier(ADMIN_WALLET);
    }

    // ==========================================
    // 1. QUẢN LÝ DANH SÁCH TRƯỜNG (CHỈ ADMIN)
    // ==========================================
    
    function addVerifier(address _verifier) external onlyOwner {
        _addVerifier(_verifier);
    }

    function _addVerifier(address _verifier) internal {
        require(!isVerifier[_verifier], "Vi nay da la Truong roi");
        isVerifier[_verifier] = true;
        verifierList.push(_verifier);
        emit VerifierAdded(_verifier);
    }

    function removeVerifier(address _verifier) external onlyOwner {
        require(isVerifier[_verifier], "Vi nay khong phai la Truong");
        isVerifier[_verifier] = false;

        // Xóa khỏi mảng (Swap & Pop để tiết kiệm gas)
        for (uint256 i = 0; i < verifierList.length; i++) {
            if (verifierList[i] == _verifier) {
                verifierList[i] = verifierList[verifierList.length - 1];
                verifierList.pop();
                break;
            }
        }
        emit VerifierRemoved(_verifier);
    }

    function getVerifierList() external view returns (address[] memory) {
        return verifierList;
    }

    // ==========================================
    // 2. CHỨC NĂNG CHÍNH
    // ==========================================

    // B1. Tạo học bổng
    function createScholarship(
        string memory title,
        uint256 amount,
        uint256 slots,
        uint256 deadline,
        string memory description
    ) external {
        require(deadline > block.timestamp, "Deadline phai o tuong lai");
        require(slots > 0, "So luong suat > 0");
        
        uint256 totalRequired = amount * slots;
        
        // Chuyển tiền vào Contract
        bool success = paymentToken.transferFrom(msg.sender, address(this), totalRequired);
        require(success, "Loi chuyen tien (Check Approve)");

        scholarships[nextScholarshipId] = Scholarship({
            id: nextScholarshipId,
            title: title,
            amount: amount,
            slots: slots,
            filledSlots: 0,
            deadline: deadline,
            description: description,
            totalApplicants: 0,
            creator: msg.sender // Lưu lại người tạo
        });

        emit ScholarshipCreated(nextScholarshipId, title, amount, msg.sender);
        nextScholarshipId++;
    }

    // B2. Sinh viên nộp hồ sơ
    function applyForScholarship(uint256 scholarshipId, string memory metadata) external {
        Scholarship storage s = scholarships[scholarshipId];
        require(s.deadline > block.timestamp, "Het han nop");

        applications[scholarshipId].push(Application(msg.sender, metadata, Status.Applied));
        s.totalApplicants++;
        
        emit Applied(scholarshipId, msg.sender);
    }

    // B3. NHÀ TRƯỜNG XÁC NHẬN (Verify)
    function verifyApplicant(uint256 scholarshipId, uint256 index, bool isValid) external {
        require(isVerifier[msg.sender], "Ban khong phai Nha truong");
        
        Application storage app = applications[scholarshipId][index];
        require(app.status == Status.Applied, "Trang thai khong hop le (Phai la Applied)");

        if (isValid) {
            app.status = Status.Verified; // Hợp lệ
        } else {
            app.status = Status.Rejected; // Từ chối
        }
        emit Verified(scholarshipId, index, msg.sender, isValid);
    }

    // B4. ADMIN (CHỦ SỞ HỮU) DUYỆT (Approve)
    function approveApplicant(uint256 scholarshipId, uint256 index) external {
        Scholarship storage s = scholarships[scholarshipId];
        
        // Chỉ người tạo học bổng hoặc Admin tối cao mới được duyệt
        require(msg.sender == s.creator || msg.sender == owner(), "Khong phai chu so huu");
        
        Application storage app = applications[scholarshipId][index];
        
        // [QUAN TRỌNG] Chỉ duyệt hồ sơ ĐÃ ĐƯỢC TRƯỜNG XÁC NHẬN
        require(app.status == Status.Verified, "Ho so chua duoc Truong xac nhan");
        require(s.filledSlots < s.slots, "Hoc bong da het suat");

        app.status = Status.Approved;
        s.filledSlots++; 

        emit Approved(scholarshipId, index, msg.sender);
    }

    // B5. TRẢ TIỀN (Pay)
    function payApplicant(uint256 scholarshipId, uint256 index) external {
        Scholarship storage s = scholarships[scholarshipId];
        
        // Chỉ người tạo hoặc Admin mới được bấm trả tiền
        require(msg.sender == s.creator || msg.sender == owner(), "Khong co quyen");
        
        Application storage app = applications[scholarshipId][index];
        require(app.status == Status.Approved, "Ho so chua duoc duyet (Approved)");
        require(paymentToken.balanceOf(address(this)) >= s.amount, "Contract het tien");

        app.status = Status.Paid;
        require(paymentToken.transfer(app.applicant, s.amount), "Chuyen tien that bai");

        emit Paid(scholarshipId, index, app.applicant, s.amount);
    }
}
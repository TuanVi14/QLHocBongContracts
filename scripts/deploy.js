const hre = require("hardhat");

async function main() {
  // Lấy thông tin ví deploy
  const [deployer] = await hre.ethers.getSigners();
  
  console.log("===================================================");
  console.log("🚀 BẮT ĐẦU DEPLOY SYSTEM");
  console.log("👤 Ví Deploy:", deployer.address);
  
  // Kiểm tra số dư ví deploy để tránh lỗi thiếu gas giữa chừng
  const balance = await hre.ethers.provider.getBalance(deployer.address);
  console.log("💰 Số dư ví:", hre.ethers.formatEther(balance), "ETH/CRO");
  console.log("===================================================\n");

  // --------------------------------------------------------
  // BƯỚC 1: DEPLOY TOKEN WCT
  // --------------------------------------------------------
  console.log("⏳ 1. Đang deploy Token WCT...");
  const MyToken = await hre.ethers.getContractFactory("MyToken");
  
  // Nếu constructor của Token không cần tham số thì để trống
  const token = await MyToken.deploy(); 
  await token.waitForDeployment();
  
  const tokenAddress = await token.getAddress();
  console.log("✅ WCT Token deployed at:", tokenAddress);

  // --------------------------------------------------------
  // BƯỚC 2: DEPLOY MANAGER (Kèm địa chỉ Token vừa tạo)
  // --------------------------------------------------------
  console.log("\n⏳ 2. Đang deploy ScholarshipManager...");
  const ScholarshipManager = await hre.ethers.getContractFactory("ScholarshipManager");
  
  // Truyền tokenAddress vào constructor của Manager
  const manager = await ScholarshipManager.deploy(tokenAddress);
  await manager.waitForDeployment();
  
  const managerAddress = await manager.getAddress();
  console.log("✅ ScholarshipManager deployed at:", managerAddress);

  // --------------------------------------------------------
  // BƯỚC 3: IN THÔNG TIN CẤU HÌNH CHO FRONTEND
  // --------------------------------------------------------
  console.log("\n===================================================");
  console.log("⚠️  HÀNH ĐỘNG CẦN LÀM NGAY CHO FRONTEND  ⚠️");
  console.log("===================================================");
  
  console.log("1️⃣  Mở file 'src/services/eth.js' và thay thế bằng:");
  console.log("---------------------------------------------------");
  console.log(`export const MANAGER_ADDRESS = "${managerAddress}";`);
  console.log(`export const TOKEN_ADDRESS = "${tokenAddress}";`);
  console.log("---------------------------------------------------");

  console.log("2️⃣  Cập nhật ABI (Rất quan trọng để không bị lỗi):");
  console.log("   👉 Copy: artifacts/contracts/ScholarshipManager.sol/ScholarshipManager.json");
  console.log("   👉 Dán đè vào: src/contracts/ScholarshipManager.json");
  console.log("\n   👉 Copy: artifacts/contracts/MyToken.sol/MyToken.json");
  console.log("   👉 Dán đè vào: src/contracts/MyToken.json");
  console.log("===================================================");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
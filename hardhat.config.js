require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.20",
  networks: {
    cronos_testnet: {
      url: "https://evm-t3.cronos.org",
      chainId: 338,
      accounts: [process.env.PRIVATE_KEY], // Lấy Private Key từ file .env
      gasPrice: "auto"
    },
  },
  etherscan: {
    apiKey: {
      cronos_testnet: "NO_API_KEY_NEEDED", 
    },
    customChains: [
      {
        network: "cronos_testnet",
        chainId: 338,
        urls: {
          apiURL: "https://api-testnet.cronoscan.com/api",
          browserURL: "https://testnet.cronoscan.com",
        },
      },
    ],
  },
};
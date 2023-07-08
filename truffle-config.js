const HDWalletProvider = require("@truffle/hdwallet-provider");
const dotenv = require("dotenv");
dotenv.config();

const PRIVATE_KEY_ETHEREUM_GOERLI =
  process.env.PRIVATE_KEY_ETHEREUM_GOERLI || null;
  const PRIVATE_KEY_POLYGON_MUMBAI =
  process.env.PRIVATE_KEY_POLYGON_MUMBAI || null;

const ETHERSCAN_API_KEY = process.env.ETHERSCAN_API_KEY;
const POLYGONSCAN_API_KEY = process.env.POLYGONSCAN_API_KEY;

const INFURA_PROJECT_ID = process.env.INFURA_PROJECT_ID;

module.exports = {
  networks: {
    development: {
      host: "127.0.0.1", // Localhost (default: none)
      port: 8545, // Standard Ethereum port (default: none)
      network_id: "*", // Any network (default: none)
      skipDryRun: true,
      gas: 8000000,
    },
    mumbai: {
      provider: function () {
        return new HDWalletProvider(
          [PRIVATE_KEY_POLYGON_MUMBAI],
          `wss://ws-nd-167-327-503.p2pify.com/b2d91710eccfa52220a46da03987c465`
        );
      },
      network_id: 80001,
      gas: 20000000,
      gasPrice: 300000000000,
      skipDryRun: true,
      networkCheckTimeout: 100000000,
      timeoutBlocks: 200,
    },
    goerli: {
      provider: () =>
        new HDWalletProvider({
          privateKeys: [PRIVATE_KEY_ETHEREUM_GOERLI],
          providerOrUrl: `https://goerli.infura.io/v3/${INFURA_PROJECT_ID}`,
        }),
      network_id: 5,
      gas: 20000000,
      gasPrice: 100000000000,
      skipDryRun: true,
      networkCheckTimeout: 100000000,
      timeoutBlocks: 200,
    },
    sepolia: {
      provider: function () {
        return new HDWalletProvider(
          [PRIVATE_KEY_ETHEREUM_GOERLI],
          `https://endpoints.omniatech.io/v1/eth/sepolia/public`,
        );
      },
      network_id: 11155111,
      gas: 5000000,
      gasPrice: 1000000000,
      skipDryRun: true,
      networkCheckTimeout: 100000000,
      timeoutBlocks: 200,
    },
  },
  api_keys: {
    etherscan: ETHERSCAN_API_KEY,
    polygonscan: POLYGONSCAN_API_KEY,
  },
  plugins: [
    "truffle-contract-size",
    "truffle-plugin-verify",
    "truffle-flatten",
  ],
  mocha: {
    reporter: "eth-gas-reporter",
    reporterOptions: {
      excludeContracts: ["Migrations"],
    },
  },
  compilers: {
    solc: {
      version: "0.8.17",
      settings: {
        optimizer: {
          enabled: true,
          runs: 200,
        },
        viaIR: false,
      },
    },
  },
  db: {
    enabled: false,
  },
};

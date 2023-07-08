const { deployProxy, upgradeProxy } = require("@openzeppelin/truffle-upgrades");
const ethers = require("ethers");
const fs = require("fs");

const BlackdoveNFT = artifacts.require("BlackdoveNFT");
const AuctionManager = artifacts.require("AuctionManager");

module.exports = async function (deployer) {
  // Deploy BlackdoveNFT
  const blackdoveNFT = await deployProxy(
    BlackdoveNFT,
    [
      "Blackdove Marketplace Collection",
      "BD",
      "https://ipfs.io/ipfs/1/",
      "https://ipfs.io/ipfs/2/",
      5,
      500
    ],
    {
      deployer: deployer,
      initializer: "initialize",
    }
  );
  console.log(`BlackdoveNFT contract deployed to: ${blackdoveNFT.address}`);

  // const blackdoveNFTUpgrade = await upgradeProxy(
  //   "0xf283ad0008091D2781C2e8fF6e9454d02Aee2911",
  //   BlackdoveNFT,
  //   { deployer }
  // );
  // console.log(
  //   `BlackdoveNFT contract upgraded to: ${blackdoveNFTUpgrade.address}`
  // );

  // Deploy AuctionManager
  const auctionManager = await deployProxy(
    AuctionManager,
    [
      blackdoveNFT.address,
      [
        // [
        //   "0x6ab537BDbdB6913a4F68DF3b16c78C07c0647e2c",
        //   ethers.BigNumber.from("290"), // 2.9%
        // ],
      ],
      25,
      2500,
    ],
    {
      deployer: deployer,
      initializer: "initialize",
    }
  );
  console.log(`AuctionManager contract deployed to: ${auctionManager.address}`);

  // const auctionManagerUpgrade = await upgradeProxy(
  //   "0x6a931D52FF29e8A23ca5a664581108458Ef6f322",
  //   AuctionManager,
  //   { deployer }
  // );
  // console.log(`AuctionManager contract upgraded to: ${auctionManagerUpgrade.address}`);



  let config = `module.exports.BlackdoveNFT = "${blackdoveNFT.address}";
module.exports.AuctionManager = "${auctionManager.address}";`;

  let data = JSON.stringify(config);
  fs.writeFileSync("addresses.js", JSON.parse(data));
};

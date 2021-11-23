const { expect } = require("chai");
const { ethers } = require("hardhat");
const { tokens, tokensDec } = require("../utils/utils");

const ENTERED_EVENT = "0x089d0daa5e8466fdfdab1113e8fdd98c06ef26711cafc429dabce354d007364e";
const SINGLE_REQESTID = 0;
const ONE_THOUSAND_USDT = tokensDec(1_000, 6);

describe("Stake USDT tokens", function () {
  let emiTracking, usdt;
  beforeEach("prepare environment", async () => {
    [UpgradeAdmin, owner, user1, user2, user3, user4, ...signers] = await ethers.getSigners();

    const USDT = await ethers.getContractFactory("USDT");
    usdt = await USDT.deploy();

    await usdt.transfer(user1.address, tokensDec(10_000, 6));

    const EMITRACKING = await ethers.getContractFactory("EmiTracking");
    emiTracking = await upgrades.deployProxy(EMITRACKING, [owner.address, usdt.address]);
    await emiTracking.deployed();
  });
  it("Make correct enter stake", async () => {
    await usdt.connect(user1).approve(emiTracking.address, ONE_THOUSAND_USDT);
    let resTx = await emiTracking.connect(user1).enter(ONE_THOUSAND_USDT);
    let eEntered = (await resTx.wait()).events.filter((x) => {
      return x.topics[0] == ENTERED_EVENT;
    });

    // chech wallet and amount from event "entered"
    expect(eEntered[0].args[0]).to.be.equal(user1.address);
    expect(eEntered[0].args[1]).to.be.equal(ONE_THOUSAND_USDT);

    // get requests by wallet
    let requestIds = await emiTracking.getWalletEnterRequests(user1.address);
    expect(requestIds.length).to.be.equal(1);
    expect(requestIds[0]).to.be.equal(SINGLE_REQESTID);

    // get wallet enter requestIds
    let enterRequestData = await emiTracking.getEnterRequestData(SINGLE_REQESTID);
    expect(enterRequestData.wallet).to.be.equal(user1.address);
    expect(enterRequestData.amount).to.be.equal(ONE_THOUSAND_USDT);
  });
});

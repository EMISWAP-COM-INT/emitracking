const { expect } = require("chai");
const { ethers } = require("hardhat");
const { tokens, tokensDec } = require("../utils/utils");

const ENTERED_EVENT = "0xa9cf4922f2856a66149c9a3bf0008b3792335527ce5112f6d19fe9533e54349f";
const SINGLE_REQESTID = 0;
const ONE_THOUSAND_USDT = tokensDec(1_000, 6);
const THREE_HUNDRED_FLEX = tokens(300);

const TOKENREQUEST_Pending = 0;
const TOKENREQUEST_Refunded = 1;
const TOKENREQUEST_Finalised = 2;

describe("Stake USDT tokens", function () {
  let emiTracking, usdt, tokenRequest;
  beforeEach("prepare environment", async () => {
    [UpgradeAdmin, owner, vault, user1, user2, user3, user4, ...signers] = await ethers.getSigners();

    const USDT = await ethers.getContractFactory("USDT");
    usdt = await USDT.deploy();

    // mock TokenRequest
    const TOKENREQUEST = await ethers.getContractFactory("TokenRequest");
    tokenRequest = await TOKENREQUEST.deploy();
    await tokenRequest.initialize(vault.address, [usdt.address]);

    await usdt.transfer(user1.address, tokensDec(10_000, 6));

    const EMITRACKING = await ethers.getContractFactory("EmiTracking");
    emiTracking = await upgrades.deployProxy(EMITRACKING, [owner.address, usdt.address, tokenRequest.address]);
    await emiTracking.deployed();
  });
  it("Make correct enter stake", async () => {
    await usdt.connect(user1).approve(emiTracking.address, ONE_THOUSAND_USDT);
    let resTx = await emiTracking.connect(user1).enter(ONE_THOUSAND_USDT, THREE_HUNDRED_FLEX);
    let eEntered = (await resTx.wait()).events.filter((x) => {
      return x.topics[0] == ENTERED_EVENT;
    });

    // chech wallet and amount from event "entered"
    expect(eEntered[0].args[0]).to.be.equal(user1.address);
    expect(eEntered[0].args[1]).to.be.equal(ONE_THOUSAND_USDT);
    expect(eEntered[0].args[2]).to.be.equal(THREE_HUNDRED_FLEX);
    expect(eEntered[0].args[3]).to.be.equal(0);

    // get requests by wallet
    let requestIds = await emiTracking.getWalletEnterRequests(user1.address);
    expect(requestIds.length).to.be.equal(1);
    expect(requestIds[0]).to.be.equal(SINGLE_REQESTID);

    // get wallet enter requestIds
    let enterRequestData = await emiTracking.getEnterRequestData(SINGLE_REQESTID);
    expect(enterRequestData.wallet).to.be.equal(user1.address);
    expect(enterRequestData.amount).to.be.equal(ONE_THOUSAND_USDT);
  });
  it("Make multiple correct enter stake", async () => {
    for (const i of Array(10).keys()) {
      await usdt.connect(user1).approve(emiTracking.address, ONE_THOUSAND_USDT);
      let resTx = await emiTracking.connect(user1).enter(ONE_THOUSAND_USDT, THREE_HUNDRED_FLEX);
      let eEntered = (await resTx.wait()).events.filter((x) => {
        return x.topics[0] == ENTERED_EVENT;
      });

      // chech wallet and amount from event "entered"
      expect(eEntered[0].args[0]).to.be.equal(user1.address);
      expect(eEntered[0].args[1]).to.be.equal(ONE_THOUSAND_USDT);
      expect(eEntered[0].args[2]).to.be.equal(THREE_HUNDRED_FLEX);
      expect(eEntered[0].args[3]).to.be.equal(i);

      // get requests by wallet
      let requestIds = await emiTracking.getWalletEnterRequests(user1.address);
      expect(requestIds.length).to.be.equal(i + 1);
      expect(requestIds[i]).to.be.equal(i);

      // get wallet enter requestIds
      let enterRequestData = await emiTracking.getEnterRequestData(SINGLE_REQESTID);
      expect(enterRequestData.wallet).to.be.equal(user1.address);
      expect(enterRequestData.amount).to.be.equal(ONE_THOUSAND_USDT);

      // get enter request from tokenRequest
      let enterRequest = await emiTracking.getEnterRequest(i);

      expect(enterRequest[0]).to.be.equal(emiTracking.address);
      expect(enterRequest[1]).to.be.equal(usdt.address);
      expect(enterRequest[2]).to.be.equal(ONE_THOUSAND_USDT);
      expect(enterRequest[3]).to.be.equal(THREE_HUNDRED_FLEX);
      expect(enterRequest[4]).to.be.equal(TOKENREQUEST_Pending);
    }
  });
  it("Make enter stake and finaliseTokenRequest on berezka", async () => {
    await usdt.connect(user1).approve(emiTracking.address, ONE_THOUSAND_USDT);
    await emiTracking.connect(user1).enter(ONE_THOUSAND_USDT, THREE_HUNDRED_FLEX);

    let requestIds = await emiTracking.getWalletEnterRequests(user1.address);

    await tokenRequest.finaliseTokenRequest(requestIds[0]);

    // get enter request from tokenRequest
    let enterRequest = await emiTracking.getEnterRequest(requestIds[0]);

    expect(enterRequest[0]).to.be.equal(emiTracking.address);
    expect(enterRequest[1]).to.be.equal(usdt.address);
    expect(enterRequest[2]).to.be.equal(ONE_THOUSAND_USDT);
    expect(enterRequest[3]).to.be.equal(THREE_HUNDRED_FLEX);
    expect(enterRequest[4]).to.be.equal(TOKENREQUEST_Finalised);
  });
});

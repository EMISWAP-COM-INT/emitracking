const { expect } = require("chai");
const { ethers } = require("hardhat");
const { tokens, tokensDec } = require("../utils/utils");

const ENTERED_EVENT = "0x089d0daa5e8466fdfdab1113e8fdd98c06ef26711cafc429dabce354d007364e";

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
    await usdt.connect(user1).approve(emiTracking.address, tokensDec(1_000, 6));
    let resTx = await emiTracking.connect(user1).enter(tokensDec(1_000, 6));
    //console.log("resTx", resTx);
    let eEntered = (await resTx.wait()).events.filter((x) => {
      //console.log("x", x);
      return x.topics[0] == ENTERED_EVENT;
    });
    console.log("eEntered", eEntered[0].args[0], eEntered[0].args[1].toString());

    // chech wallet and amount from event "entered"
    expect(eEntered[0].args[0]).to.be.equal(user1.address);
    expect(eEntered[0].args[1]).to.be.equal(tokensDec(1_000, 6));
  });
});

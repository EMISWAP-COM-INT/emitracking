const { BigNumber } = require("@ethersproject/bignumber");

function tokens(val) {
  return BigNumber.from(val).mul(BigNumber.from("10").pow(18)).toString();
}

function tokensDec(val, dec) {
  return BigNumber.from(val).mul(BigNumber.from("10").pow(dec)).toString();
}

module.exports = {
  tokens,
  tokensDec,
};

/* eslint-disable no-plusplus */
const fs = require('fs');

function formatVKey(vkey) {
  const ic = [];
  for (let i = 0; i < vkey.IC.length; i++) {
    ic.push({ x: BigInt(vkey.IC[i][0]), y: BigInt(vkey.IC[i][1]) });
  }
  return {
    alpha1: {
      x: BigInt(vkey.vk_alpha_1[0]),
      y: BigInt(vkey.vk_alpha_1[1]),
    },
    beta2: {
      x: [BigInt(vkey.vk_beta_2[0][1]), BigInt(vkey.vk_beta_2[0][0])],
      y: [BigInt(vkey.vk_beta_2[1][1]), BigInt(vkey.vk_beta_2[1][0])],
    },
    gamma2: {
      x: [BigInt(vkey.vk_gamma_2[0][1]), BigInt(vkey.vk_gamma_2[0][0])],
      y: [BigInt(vkey.vk_gamma_2[1][1]), BigInt(vkey.vk_gamma_2[1][0])],
    },
    delta2: {
      x: [BigInt(vkey.vk_delta_2[0][1]), BigInt(vkey.vk_delta_2[0][0])],
      y: [BigInt(vkey.vk_delta_2[1][1]), BigInt(vkey.vk_delta_2[1][0])],
    },
    ic,
  };
}

function getVerificationKeys() {
  const vkJS = formatVKey(JSON.parse(fs.readFileSync('./build/JoinSplit.json')));
  const vkOwn = formatVKey(JSON.parse(fs.readFileSync('./build/Ownership.json')));
  const vkJSOptimized = formatVKey(JSON.parse(fs.readFileSync('./build/JoinSplitOptimized.json')));
  const vkOwnOptimized = formatVKey(JSON.parse(fs.readFileSync('./build/OwnershipOptimized.json')));
  return [vkJS, vkOwn, vkJSOptimized, vkOwnOptimized];
}
module.exports = {
  getVerificationKeys,
};

const { network, getNamedAccounts } = require('hardhat');
const { developmentChains } = require('../helper-hardhat-config');
const { verify } = require('../utils/verify');

module.exports = async ({ deployments }) => {
	const { deploy, log } = deployments;
	const { deployer } = await getNamedAccounts();

	const args = [];
	const basicNFT = await deploy('BasicNft', {
		from: deployer,
		args: args,
		log: true,
		waitConfirmations: network.config.blockConfirmations || 1,
	});

	const basicNftTwo = await deploy('BasicNftTwo', {
		from: deployer,
		args: args,
		log: true,
		waitConfirmations: network.config.blockConfirmations || 1,
	});

	if (
		!developmentChains.includes(network.name) &&
		process.env.ETHERSCAN_API_KEY
	) {
		log('Verifying...');
		await verify(basicNFT.address, args);
		await verify(basicNftTwo.address, args);
	}
};

module.exports.tags = ['all', 'basicNft'];

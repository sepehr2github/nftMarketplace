const { network, getNamedAccounts } = require('hardhat');
const { developmentChains } = require('../helper-hardhat-config');
const { verify } = require('../utils/verify');

module.exports = async ({ getNamedAccount, deployments }) => {
	const { deploy, log } = deployments;
	const { deployer } = await getNamedAccounts();

	args = []; // because there are no constructor

	const nftMarketplace = await deploy('NFTMarketplace', {
		from: deployer,
		args: args,
		log: true,
		waitConfirmations: network.config.blockConfirmations || 1,
	});

	if (
		!developmentChains.includes(network.name) &&
		process.env.ETHERSCAN_API_KEY
	) {
		log('verifying');
		await verify(nftMarketplace.address, args);
	}

	log('----------------------------------------');
};

module.exports.tags = ['all', 'nftMarketplace'];

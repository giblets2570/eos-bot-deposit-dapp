module.exports = {
  // See <http://truffleframework.com/docs/advanced/configuration>
  // to customize your Truffle configuration!
  networks: {
    development: {
      host: 'localhost',
      port: 8545,
      network_id: '*' // Match any network id
    },
    kovan: {
      // protocol: 'https',
      // host: 'kovan.infura.io/5UyreKP8Xw5prCRt5yGr',
      // port: 443,
      host: 'localhost',
      port: 8545,
      network_id: 42,
      gas: 4000000
    }
  }
}
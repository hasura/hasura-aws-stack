const { ApolloServer, gql } = require('apollo-server');
const Sequelize = require("sequelize");
const {Account, MinAmount, sequelize} = require('./models.js');

const typeDefs = gql`
  type Query {
    hello:  String
  }

  type Mutation {
    validate_and_add_account(name: String, balance: Int): Account
  }

  type Account {
    id:       Int
    name:     String
    balance:  Int
  }
`;


// We consider a account schema where an account can be added only if a custom validation passes.
// The custom validation involves fetching a min amount from a table
// and checking if the account balance is greater than the min amount.
// This will be done in a transaction.

const resolvers = {
    Query: {
        hello: () => "world",
    },
    Mutation: {
        validate_and_add_account: async (_, { name, balance }) => {
            //begin transaction
            return await sequelize.transaction(async (t) => {
                try {
                    //fetch min amount
                    const minAmount = await MinAmount.findOne({}, {transaction: t});
                    //check balance
                    if (balance >= minAmount.amount) {
                        //create account if balance is greater
                        const account = await Account.create({
                            name: name,
                            balance: balance
                        });
                        return account;
                    } else {
                        throw new Error("balance too low, required atleast " + minAmount.amount);
                    }
                } catch (e) {
                    console.log(e);
                    throw new Error(e);
                }
            });
        }
    }
};

const serverLocal = new ApolloServer({ typeDefs, resolvers });

serverLocal.listen().then(({ url }) => {
    console.log(`Server ready at ${url}`);
});

exports.typeDefs = typeDefs;
exports.resolvers = resolvers;

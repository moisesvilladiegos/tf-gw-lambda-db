const AWS = require("aws-sdk");
const dynamo = new AWS.DynamoDB.DocumentClient();

const TABLE = process.env.TABLE;

exports.handler = async (event, context) => {
  let body;
  let statusCode = 200;

  const headers = {
    "Content-Type": "application/json"
  };

  try {
    body = {
      id: event.pathParameters.id
    }

    await dynamo.delete({
      TableName: TABLE,
      Key: {
        id: body.id
      }
    }).promise();
  } catch (error) {
    statusCode = 400;
    body = error.message;
  } finally {
    const response = {
      ...body,
      "message": "Item eliminado correctamente"
    }
    body = JSON.stringify(response);
  }

  return {
    statusCode,
    body,
    headers
  };
};
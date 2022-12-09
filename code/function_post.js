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
    let requestJSON = JSON.parse(event.body);
    body = {
      id: requestJSON.id,
      materia: requestJSON.materia,
      profesor: requestJSON.profesor
    };

    

    await dynamo.put({ TableName: TABLE, Item: body }).promise();
  } catch (error) {
    statusCode = 400;
    body = error.message;
  } finally {
    const response = {
      ...body,
      "message": "Item guardado correctamente"
    }
    body = JSON.stringify(response);
  }

  return {
    statusCode,
    body,
    headers
  };
};
exports.handler = async (event) => {
  console.log('Event received:', JSON.stringify(event, null, 2));

  const response = {
    statusCode: 200,
    headers: {
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      message: 'Hello from Lambda!'
    })
  };

  return response;
};
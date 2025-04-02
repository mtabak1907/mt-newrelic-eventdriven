exports.handler = async (event) => {
    console.log("Hello from Node.js Lambda");
    return {
        statusCode: 200,
        body: 'Hello, World!'
    };
};

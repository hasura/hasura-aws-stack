const echo = require('./index').echo;

exports.handler = (event, context, callback) => {
    const hasuraEvent = JSON.parse(event.body);
    console.log(`processing event ${hasuraEvent.id}`);
    try {
        var result = echo(hasuraEvent.event);
        return callback(null, {
            statusCode: 200,
            body: JSON.stringify(result)
        });
    } catch(e) {
        console.log(e);
        return callback(null, {
            statusCode: 500,
            body: e.toString()
        });
    }
};

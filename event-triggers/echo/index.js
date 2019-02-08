// Lambda which just echoes back the event data

function echo(event) {
   let responseBody = '';
    if (event.op === "INSERT") {
        responseBody = `New user ${event.data.new.id} inserted, with data: ${event.data.new.name}`;
    }
    else if (event.op === "UPDATE") {
        responseBody = `User ${event.data.new.id} updated, with data: ${event.data.new.name}`;
    }
    else if (event.op === "DELETE") {
        responseBody = `User ${event.data.old.id} deleted, with data: ${event.data.old.name}`;
    }

    return responseBody;
};

exports.echo = echo;

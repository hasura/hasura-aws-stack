const express = require('express');
const bodyParser = require('body-parser');
const app = express();

const echo = require('../event-triggers/echo').echo;

app.use(bodyParser.json());

app.post('/echo', function (req, res) {
    try{
        var result = echo(req.body.event);
        res.json(result);
    } catch(e) {
        console.log(e);
        res.status(500).json(e.toString());
    }
});

var server = app.listen(8081, function () {
    console.log("server listening on port 8081");
});

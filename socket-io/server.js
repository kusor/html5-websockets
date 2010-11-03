var http  = require('http'),
    url   = require('url'),
    fs    = require('fs'),
    path  = require('path'),
    io    = require('socket.io'),
    sys   = require('sys'),
    exec  = require('child_process').exec,
    mem   = process.memoryUsage(),
    etime = "00:00\n",
    uptime;

var server = http.createServer(function (req, res) {
  var pathname = url.parse(req.url).pathname;
  switch (pathname) {
    case '/':
    case '/index.html':
      fs.readFile(__dirname + '/public/index.html', function (err, data) {
        if (err) return send404(res);
        res.writeHead(200, {'Content-Type': 'text/html'});
        res.end(data);
      });
      break;

    case '/javascripts/json.js':
    case '/javascripts/socket-io.js':
    case '/stylesheets/main.css':
      fs.readFile(__dirname + '/public' + pathname, function (err, data) {
        if (err) return send404(res);
        res.writeHead(200, {'Content-Type': 'text/' + path.extname(pathname).replace(/\./, '')});
        res.end(data);
      });
      break;

    case '/images/logo.png':
    case '/images/logo-dev.png':
    case '/images/tab.gif':
      fs.readFile(__dirname + '/public' + pathname, function (err, data) {
        if (err) return send404(res);
        res.writeHead(200, {'Content-Type': 'image/' + path.extname(pathname).replace(/\./, '')});
        res.end(data);
      });
      break;

    case '/favicon.ico':
      fs.readFile(__dirname + '/public' + pathname, function (err, data) {
        if (err) return send404(res);
        res.writeHead(200, {'Content-Type': 'image/vnd.microsoft.icon'});
        res.end(data);
      });
      break;

    default: send404(res);
  }
});

var send404 = function (res) {
  res.writeHead(404);
  res.end('404');
};

server.listen(8004);


var io = io.listen(server),
    nicks = {},
    roaster = function () {
      var out = new Array();
      for(var p in nicks) {
        out.push(nicks[p])
      }
      return out;
    };


setInterval(function() {
  uptime = exec('ps -o etime= -p ' + process.pid, 
    function (error, stdout, stderr) {
      etime = stdout;
      if (error !== null) {
        sys.log('exec error: ' + error);
      }
      if (stderr) {
        sys.log('stderr: ' + stderr);
      };
  });
}, 30*1000);

io.on('connection', function (client) {
  var username = "user_" + client.sessionId;
  nicks[client.sessionId] = username;
  sys.log(sys.inspect(nicks));
  client.send(JSON.stringify({
    'info': "Welcome. Type '/help' for more information."
  }));

  client.broadcast(JSON.stringify({
    'info' : "User '" + username + "' connected!"
  }));

  client.send(JSON.stringify({'roaster': roaster() }));
  client.broadcast(JSON.stringify({'roaster': roaster() }));

  setInterval(function () {
    client.send(JSON.stringify({
      'stats': {
        'rss': (mem.rss/(1024*1024)).toFixed(2),
        'uptime': etime.replace(/\n$/, "")
      }
    }));
  }, 30*1000);

  client.on('message', function (msg) {
    if (msg[0] == "/") {
      if ( (matches = msg.match(/^\/nick (\w+)$/i)) && matches[1] ) {
        nicks[client.sessionId] = matches[1];

        client.send(JSON.stringify({
          'info': "Successfully changed nick to '" + matches[1] + "'"
        }));

        client.broadcast(JSON.stringify({
          'info' : "User '" + username + "' is now known as '" + matches[1] + "'"
        }));

        username = matches[1];
        client.send(JSON.stringify({'roaster': roaster() }));
        client.broadcast(JSON.stringify({'roaster': roaster() }));

      } else if(/^\/help/.test(msg)){
          client.send(JSON.stringify({'info': [
            "Type '/nick USERNAME' to change your username.",
            "Type '/quit' to exit."
          ]}));
      }
    } else {
      var m = JSON.stringify({
        'message': "<" + username + ">: " + msg
      });
      client.send(m);
      client.broadcast(m);
    };
  });


  client.on('disconnect', function () {
    
    delete nicks[client.sessionId];
    
    client.broadcast(JSON.stringify({
      'info':"User '" + username + "' left the channel."
    }));

    client.broadcast(JSON.stringify({'roaster': roaster() }));
  });

});


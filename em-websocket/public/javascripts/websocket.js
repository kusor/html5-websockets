$(function(){
  var history = [],
      idx = 0,
      logpanel = $("#log"),
      last = '',
      ws;

  // $("#entry").focus();

  $(window).bind("focus", function () {
    $("#entry").focus();
  });

  function sendmsg () {
    if(ws && ws.readyState == 1){
      var msg = $("#entry").val().replace(/\n$/, "");
      if (msg.match(/^\s*$/) === null) {
        history.unshift(msg);
        ws.send(msg);
        idx = 0;
      };
      $("#entry").val("");
    }
  };

  $("#entry").bind("keydown", function (e) {
    if(e.which == 13){
      sendmsg();
    }
  });

  $("#connect").bind("click", function () {
    connect();
  });

  $("#disconnect").bind("click", function () {
    ws.close();
  });

  function scrollToBottom () {
    $('#content').scrollTop($('#log').height() - $('#header').height() - $('#controls').height());
  };

  function log (data) {
    var o =  jQuery.parseJSON(data);

    if (o.hasOwnProperty('message')) {
      var u = o.message.slice(0, o.message.indexOf(':')).replace(/</, '').replace(/>/, '');
      var msg = o.message.slice((o.message.indexOf(':') + 1), o.message.length);
      var html = jQuery.trim(msg)
                      .replace(/&/g, "&amp;")
                      .replace(/</g, "&lt;")
                      .replace(/>/g, "&gt;");
      
      if (last == u) {
        logpanel.append('<p class="message"><cite>'+ html +'</cite></p>');
      } else {
        logpanel.append('<p class="message"><dfn>'+ u +':</dfn> <cite>'+ html +'</cite></p>');
      };
      last = u;
    };

    if (o.hasOwnProperty('stats')) {
      $('.stats').replaceWith('<h2 class="stats">RSS: '+ o.stats['rss'] +'MB, Uptime: '+ o.stats['uptime'] +'</h2>');
    };

    if (o.hasOwnProperty('roaster')) {
      var roaster_list = '<ul id="roaster">';
      $.each(o.roaster, function (i, v) {
        roaster_list+= '<li>'+ v +'</li>';
      });
      roaster_list+= '</ul>';
      $('#roaster').replaceWith(roaster_list);
    };

    if (o.hasOwnProperty('info')) {
      last = '';
      if (typeof o.info === 'string') {
        logpanel.append('<p>'+ jQuery.trim(o.info) +'</p>');
      } else {
        for (var i = o.info.length - 1; i >= 0; i--){
          logpanel.append('<p>'+ jQuery.trim(o.info[i]) +'</p>');
        };
      };
    };

    scrollToBottom();
  };

  function connect () {
    if ("WebSocket" in window) {
      ws = new WebSocket("ws://" + window.location.hostname + ":" + window.location.port.replace(/800(\d)/, "808$1") + "/");
      
      ws.onmessage = function (m) {
        log(m.data);
      };

      ws.onclose = function () {
        logpanel.append("<p>You have been disconnected</p>");
        $("#disconnect").attr("disabled","disabled");
        $("#connect").removeAttr("disabled");
      };

      ws.onopen = function (){
        logpanel.append("<p>You have been connected</p>");
        $("#disconnect").removeAttr("disabled");
        $("#connect").attr("disabled","disabled");
        $("#entry").focus();
      };
      
      ws.onerror = function (e) {
        console.log(e);
      };
    }
  };

  $(window).unload(function () { ws.close(); ws = null; });
  connect();
});
